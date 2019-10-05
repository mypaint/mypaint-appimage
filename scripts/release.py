#!/usr/bin/env python3
# Copyright (C) 2019 Jesper Lloyd
# Released under GNU GPL v2+, read the file 'LICENSE' for more information.
"""
Python wrapper for the Github Releases API

Provides safe asset replacement and by-date deletion, in addition to
the standard functionality provided directly by the original API.

This code is not quite production-level, so use with caution.
"""

import argparse
import json
import os
import pprint
import re
import uuid

import requests
import logging

log = logging.getLogger(__file__)


def default_params(f):
    """Add instance-specific args to request method call

    Convenience decorator to avoid repetition, completely
    tied to interfaces of ReleaseManager and requests!
    """
    def wrapper(self, *args, **kwargs):
        headers = {'Authorization': 'token ' + self.auth_token}
        if 'headers' in kwargs:
            headers.update(kwargs['headers'])
        kwargs['headers'] = headers
        d = {'timeout': self.timeout}
        d.update(kwargs)
        return f(self, *args, **d)
    return wrapper


def log_response_error(response):
    log.error("HTTP status code: {code}".format(code=response.status_code))
    decoded = response.content.decode()
    try:
        log.error(json.loads(decoded)['message'])
    except json.JSONDecodeError:
        log.warning("Response content is not json data")
        log.error(decoded)
    except KeyError:
        log.error(pprint.pformat(json.loads(decoded)))


class ReleaseManager:

    API_URL_TEMPLATE = "https://api.github.com/repos/{repo_slug}/releases/"

    def __init__(
            self, repo_slug, auth_token, timeout=None
    ):
        self.base_url = self.API_URL_TEMPLATE.format(repo_slug=repo_slug)
        self.auth_token = auth_token
        self.timeout = timeout

    # Helpers

    @default_params
    def get(self, *args, **kwargs):
        return requests.get(*args, **kwargs)

    @default_params
    def post(self, *args, **kwargs):
        return requests.post(*args, **kwargs)

    @default_params
    def patch(self, *args, **kwargs):
        return requests.patch(*args, **kwargs)

    @default_params
    def delete(self, *args, **kwargs):
        return requests.delete(*args, **kwargs)

    def get_release_data(self, rel_id=None, tag=None, silent=False):
        """Fetch the release info
        Fetch release info by either id or tag.
        Exactly one of the two must be supplied.

        :param rel_id: Fetch release with this id
        :type rel_id: int
        :param tag: Fetch release with this tag
        :type tag: str
        :param silent: Suppress error messages for this function
        :type silent: bool
        :returns: (data dict, http response) if retrieval is successful.
                  (None, http response) if retrieval request is unsuccessful.
        :rtype: (dict | None, requests.Response)
        """
        if not ((rel_id is None) ^ (tag is None)):
            msg = "Exactly one of 'rel_id' and 'tag' must be provided!"
            raise ValueError(msg)
        url = self.base_url + (str(rel_id) if rel_id else "tags/" + str(tag))
        response = self.get(url)
        if response.status_code != 200:
            if not silent:
                log_response_error(response)
                log.error("Failed to fetch release!")
            info = None
        else:
            info = json.loads(response.content.decode())
        return info, response

    @staticmethod
    def _release_params(
            tag=None, name=None, body=None,
            commitish=None, draft=False, prerelease=True
    ):
        """
        Return release param dict for non-None values

        :rtype: dict
        """
        params = {
            "tag_name": tag,
            "target_commitish": commitish,
            "name": name,
            "body": body,
            "draft": draft,
            "prerelease": prerelease,
        }
        return {k: v for k, v in params.items() if v is not None}

    def create_release(
            self, tag, name=None, body=None,
            commitish=None, draft=False, prerelease=True
    ):
        """Create a new release

        :param tag: Release tag name (required, but can be the empty string)
        :type tag: str
        :param name: Name of the release
        :type name: str
        :param body: Contents of release body
        :type body: str
        :param commitish: The commit or branch the release should be based on
        :type commitish: str
        :param draft: Whether created release is a draft or not
        :type draft: bool
        :param prerelease: Whether or not the release is a prerelease
        :type prerelease: bool

        :return: (True, http response) if creation is successful,
                 (False, http response) if creation request is unsuccessful.
                 (False, None) if the release already exists.
        :rtype: (bool, requests.Response | None)
        """
        if not draft and self.get_release_data(tag=tag, silent=True)[0]:
            log.error("Release tag already exists: " + tag)
            return False, None
        release_data = self._release_params(
            tag=tag, name=name, body=body, commitish=commitish,
            draft=draft, prerelease=prerelease
        )
        response = self.post(self.base_url[:-1], json=release_data)
        if response.status_code != 201:
            log_response_error(response)
            log.error("Failed to create release!")
        else:
            print(json.loads(response.content.decode())['id'])
        return response.status_code == 201, response

    def edit_release(
            self, rel_id, new_tag=None, name=None, body=None,
            commitish=None, draft=None, prerelease=None
    ):
        """Edit an existing release

        :param rel_id: Id of the release to edit
        :param new_tag: Change existing tag to this value
        :param name: Change the release name/title to this value
        :param body: Change the contents of the release body to this
        :param commitish: Change what the release points to
        :param draft: Set the draft status of the release
        :param prerelease: Set the prerelease status of the release

        :return: (True, http response) if edit is successful,
                 (False, http response) if edit request is unsuccessful.
                 (False, None) if no params or if release cannot be accessed
        :rtype: (bool, requests.Response | None)
        """
        data = self._release_params(
            tag=new_tag, name=name, body=body, commitish=commitish,
            draft=draft, prerelease=prerelease
        )
        if not data:
            log.error("No edit parameters supplied!")
            return False, None

        response = self.patch(
            self.base_url + "{id}".format(id=rel_id), json=data
        )
        if response.status_code != 200:
            log_response_error(response)
            log.error("Failed to edit release!")
        return response.status_code == 200, response

    def edit_release_by_tag(self, tag, **kwargs):
        info, _ = self.get_release_data(tag=tag)
        if not info:
            log.error("Release not found, cannot edit!")
            return False, None
        return self.edit_release(info['id'], **kwargs)

    def delete_release(self, release_id):
        """Delete the release if it exists

        :param release_id: Id of the release to delete
        :return: (True, http response) if deletion is successful.
                 (False, http response) if deletion request is unsuccessful.
                 (False, None) if the release cannot be accessed.
        :rtype: (bool, requests.Response | None)
        """
        response = self.delete(self.base_url + "{id}".format(id=release_id))
        if response.status_code != 204:
            log_response_error(response)
            log.error("Failed to delete release!")
        return response.status_code == 204, response

    def delete_release_by_tag(self, tag):
        info, _ = self.get_release_data(tag=tag)
        if not info:
            log.error("Release not found; nothing deleted!")
            return False, None
        return self.delete_release(info['id'])

    def _upload_preconditions(self, asset_path, asset_name,
                              rel_id=None, tag=None, ignore_existing=False):
        """Check preconditions for asset upload

        :return: (fulfilled, release_info or None)
        """
        if not os.path.isfile(asset_path):
            log.error("File does not exist: {path}".format(path=asset_path))
            return False, None

        info, _ = self.get_release_data(tag=tag, rel_id=rel_id)
        if not info:
            log.error("Release data could not be retrieved, cannot upload.")
            return False, None

        existing = {a['name']: a['id'] for a in info['assets']}
        if not ignore_existing and asset_name in existing:
            log.error(
                "Asset '{name}' already exists, not uploading!".format(
                    name=asset_name
                )
            )
        return asset_name not in existing, info

    def upload_asset(
            self, asset_path, tag=None, rel_id=None,
            asset_name=None, asset_label=None
    ):
        """Upload a single file as a release asset

        Preconditions:
            The asset_path string must be a valid path to an existing file.
            The release id or release tag ust exist (only one must be given).
            An asset with the same name cannot exist in the same release.

        :param asset_path: File path to the asset that will be uploaded
        :param tag: Tag of release to upload to (use this or rel_id)
        :param rel_id: Id of release to upload to (use this or tag)
        :param asset_name: Name to use instead of the file name (optional)
        :param asset_label: Label to display in the asset list (optional)
        :return: (True, http response) if asset upload is successful.
                 (False, http response) if asset upload is unsuccessful.
                 (False, None) if preconditions are not met.
        """
        # Check preconditions
        asset_name = asset_name or os.path.basename(asset_path)
        ok, info = self._upload_preconditions(
            asset_path, asset_name, tag=tag, rel_id=rel_id
        )
        if not ok:
            return False, None
        response = self._upload(asset_name, asset_label, asset_path, info)
        if response.status_code == 201:
            print(
                json.loads(response.content.decode())['id'],
                asset_name
            )
        return response.status_code == 201, response

    def edit_asset(self, asset_id, new_name=None, new_label=None):
        """Edit existing asset

        Preconditions:
            At least one of new_name or new_label must be provided

        :param asset_id: Id of asset to modify
        :param new_name: New name of the asset
        :param new_label: New label for the asset
        :return: (True, http response) if the edit is successful
                 (False, http response) if the edit request is unsuccessful
                 (False, None) if preconditions are not met.
        :rtype: (bool, requests.Response|None)
        """
        if not (new_name or new_label):
            log.error("No edit parameters supplied")
            return False, None
        data = {'name': new_name, 'label': new_label}
        response = self.patch(
            self.base_url + "assets/{id}".format(id=asset_id),
            json={k: v for k, v in data.items() if v is not None}
        )
        if response.status_code != 200:
            log_response_error(response)
            log.error("Failed to edit asset!")
        return response.status_code == 200, response

    def _upload(self, asset_name, asset_label, asset_path, release_info):
        url = release_info['upload_url']
        # Strip away the example parameters in braces
        url = url[:url.rindex('{') - len(url)]
        url += "?name={name}".format(name=asset_name)
        if asset_label:
            url += "&label={label}".format(label=asset_label)
        headers = {
            'Accept': 'application/vnd.github.manifold-preview',
            'Content-Type': 'application/octet-stream',
        }
        with open(asset_path, "rb") as f:
            response = self.post(
                url,
                headers=headers,
                data=f
            )
        if response.status_code != 201:
            log_response_error(response)
            log.error(
                "Upload of '{path}' failed".format(
                    path=asset_path
                )
            )
        return response

    def delete_oldest_assets(self, max_assets, rel_id=None, tag=None):
        info, _ = self.get_release_data(rel_id=rel_id, tag=tag)
        assets = sorted(info['assets'], key=lambda a: a['updated_at'])
        success = True
        acc_responses = []
        if len(assets) > max_assets:
            for asset in assets[:len(assets) - max_assets]:
                log.info("Deleting asset '{name}'".format(
                    name=asset['name']
                ))
                ok, response = self.delete_asset(asset['id'])
                success = success and ok
                acc_responses.append(response)
        return success, acc_responses

    def delete_asset(self, a_id):
        """Delete asset with the given id

        :param a_id: asset id
        :type a_id: int
        :return: (True, http response) if deletion was successful.
                 (False, http response) if deletion was unsuccessful.
        """
        response = self.delete(self.base_url + "assets/{id}".format(id=a_id))
        if response.status_code != 204:
            log_response_error(response)
            log.error("Failed to delete asset!")
        return response.status_code == 204, response

    def replace_asset(
            self, asset_path, rel_id=None, tag=None,
            asset_name=None, asset_label=None
    ):
        """Replace any existing asset with the same name

        If the asset does not already exist, upload as usual.
        The new asset is uploaded first with a random prefix, followed by the
        deletion of the old asset and renaming of the new asset.
        The deletion of the old asset will only happen if the new file is
        successfully uploaded, but if either the deletion or the edit fails
        manual intervention will be required (this should only happen in case
        of network errors or if the authorization is changed mid-operation).

        :param asset_path: File path to the asset that will be uploaded
        :param rel_id: Id of release to upload to (use this or tag)
        :param tag: Tag of release to upload to (use this or rel_id)
        :param asset_name: Name to use instead of the file name (optional)
        :param asset_label: Label to display in the asset list (optional)
        :return: (True, http response) if asset replacement is successful.
                 (False, http response) if asset replacement is unsuccessful.
                 (False, None) if preconditions are not met.
        """
        asset_name = asset_name or os.path.basename(asset_path)
        ok, info = self._upload_preconditions(
            asset_path, asset_name, tag=tag, rel_id=rel_id,
            ignore_existing=True
        )
        if ok:  # Just upload as usual
            response = self._upload(asset_name, asset_label, asset_path, info)
            return response.status_code == 201, response
        elif not info:
            return False, None

        # Replacement required
        tmp_name = uuid.uuid4().hex + '-' + asset_name
        response = self._upload(tmp_name, asset_label, asset_path, info)
        if not response.status_code == 201:
            return False, response
        tmp_id = json.loads(response.content.decode())['id']
        cleanup_error_msg = \
            """Uploaded tmp asset:
            name: {asset_name}
            id: {asset_id}
            """.format(
                asset_name=asset_name,
                asset_id=tmp_id
            )
        old_id = {a['name']: a['id'] for a in info['assets']}[asset_name]
        deleted, del_response = self.delete_asset(old_id)
        if not deleted:
            log.error("Uploaded asset will not be edited!")
            log.error(cleanup_error_msg)
            return False, del_response
        edited, edit_response = self.edit_asset(tmp_id, new_name=asset_name)
        if not edited:
            log.error("Edit of new asset failed after old asset was deleted!")
            log.error("New asset must be renamed to complete operation!")
            log.error(cleanup_error_msg)
        return edited, edit_response


# Code below this point is only related to CLI input/verification

# Input verification functions

def file_path_value(path):
    error = None
    if not os.path.exists(path):
        error = "File does not exist: {path}"
    elif not os.path.isfile(path):
        error = "Not a file: {path}"
    if error:
        raise argparse.ArgumentTypeError(error.format(path=path))
    return path


def env_name_value(name):
    match = re.fullmatch("[^0-9=][^=]*", name)
    if not match:
        raise argparse.ArgumentTypeError(
            '"{var_name}" is not a valid environment variable name!'.format(
                var_name=name
            )
        )
    return name


def repo_slug_value(slug):
    # Only check the basic shape; exactly one '/' with something on both ends.
    if not (
        '/' in slug and
        0 < slug.index('/') < len(slug)-1 and
        slug.index('/') == slug.rindex('/')
    ):
        raise argparse.ArgumentTypeError(
            '"{invalid_slug}" is not a valid repo slug.\n'
            'A repo slug is of the form: "username/repository"'
            ''.format(invalid_slug=slug)
            )
    return slug


def max_assets_value(value):
    try:
        int_value = int(value)
        assert int_value > 0
        return int_value
    except Exception:
        raise argparse.ArgumentTypeError(
            "The maximum number of assets must be a positive integer."
        )


def true_or_false(value):
    if not value.lower() in ['true', 'false']:
        raise argparse.ArgumentTypeError(
            "Argument must be 'true' or 'false' (case insensitive)"
        )
    return value.lower() == 'true'


def get_parser():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "repo_slug", type=repo_slug_value, metavar="REPO_SLUG",
        help="The 'user/repository' combination of the release"
    )
    parser.add_argument(
        '--timeout', metavar="SECONDS", type=float,
        help="Timeout to use for network requests, default is 60 seconds"
    )
    tag_id_parser = argparse.ArgumentParser(add_help=False)
    ref_group = tag_id_parser.add_mutually_exclusive_group(required=True)
    ref_group.add_argument(
        "-t", "--tag", metavar="TAG_NAME", type=str,
        help="Identify release by tag"
    )
    ref_group.add_argument(
        "-i", "--release-id", metavar="RELEASE_ID", type=int,
        help="Identify release by id"
    )

    auth_group = parser.add_mutually_exclusive_group(required=True)
    auth_group.add_argument(
        "-a", "--auth-token-var", metavar="VAR_NAME",
        type=env_name_value,
        help="The environment variable holding the github auth token",
    )
    auth_group.add_argument(
        "-A", "--auth-token", metavar="TOKEN", type=str,
        help="Pass the github auth token directly (use with caution!)"
    )

    subparsers = parser.add_subparsers(
        title="commands", description="Commands that can be issued",
        dest='command'
    )
    subparsers.required = True

    # Common options for release creation/modification
    release_options = argparse.ArgumentParser(add_help=False)
    release_options.add_argument(
        "-n", "--name", metavar="NAME", type=str,
        help="The name of the release")
    release_options.add_argument(
        "-b", "--body", metavar="BODY", type=str,
        help="Contents of the release body")
    release_options.add_argument(
        "-c", "--commitish", metavar="COMMITISH", type=str,
        help="Commit/branch of the release")
    release_options.add_argument(
        "-p", "--prerelease", type=true_or_false,
        help="Mark release as a prerelease (default is true)"
    )
    release_options.add_argument(
        '-d', '--draft', type=true_or_false,
        help="Mark release as a draft (default is false)"
    )

    # Create release
    create_parser = subparsers.add_parser(
        'create', help="Create a new release",
        parents=[release_options]
    )
    create_parser.add_argument(
        "tag", metavar="TAG_NAME", help="Tag of the new release"
    )

    # Edit release
    edit_parser = subparsers.add_parser(
        'edit', help="Edit the release, if it exists.",
        parents=[ref_group, release_options]
    )
    edit_parser.add_argument(
        '-s', '--switch-tag-to', metavar="NEW_TAG",
        help="Switch existing tag to the provided one"
    )

    # Delete release
    subparsers.add_parser(
        'delete', help="Delete the release, if it exists.",
        parents=[ref_group]
    )

    # Common options for asset/creation modification
    asset_options = argparse.ArgumentParser(add_help=False)
    asset_options.add_argument(
        "-n", "--name", metavar="NAME", type=str,
        help="Asset name (file name when downloading)"
             " - ignored when uploading multiple files"
    )
    asset_options.add_argument(
        "-l", "--label", metavar="LABEL", type=str,
        help="Asset label (the name that is displayed)"
             " - ignored when uploading multiple files"
    )

    # Upload asset
    upload_parser = subparsers.add_parser(
        'upload-asset', help="Upload an asset file to the release",
        parents=[ref_group, asset_options]
    )
    upload_parser.add_argument(
        "-m", "--max-assets", metavar="MAX_ASSETS", type=max_assets_value,
        help="Delete the oldest assets such that this number is not exceeded"
    )
    upload_parser.add_argument(
        "-r", "--replace", action="store_true",
        help="If an asset with the same name already exists, replace it. "
              "Otherwise, nothing is uploaded."
    )
    upload_parser.add_argument(
        "asset_paths", nargs="+", metavar="FILE", type=file_path_value,
        help="File path of asset that will be added to the release."
    )

    # Edit asset
    edit_asset_parser = subparsers.add_parser(
        'edit-asset', help="Edit the name/label of an existing asset",
        parents=[asset_options], conflict_handler='resolve'
    )
    edit_asset_parser.add_argument('asset_id', metavar="ASSET_ID", type=int)

    # Delete asset
    delete_asset_parser = subparsers.add_parser(
        "delete-asset", help="Delete an existing asset"
    )
    delete_asset_parser.add_argument('asset_id', metavar="ASSET_ID", type=int)

    return parser


def verify_token(args):
    """Basic auth token checks"""
    if args.auth_token is not None:
        auth_token = args.auth_token
    else:
        auth_token = os.environ.get(args.auth_token_var)
        if auth_token is None:
            log.error(
                'The provided auth token environment variable: '
                '"{env_var}" is not defined'.format(
                    env_var=args.auth_token_var
                )
            )
            exit(1)
    if not auth_token:
        log.error("The auth token cannot be empty!")
        exit(1)
    return auth_token


def main():
    args = get_parser().parse_args()
    auth_token = verify_token(args)
    rm = ReleaseManager(
            repo_slug=args.repo_slug,
            auth_token=auth_token,
            timeout=args.timeout or 60
    )

    cmd = args.command
    rel_args = None
    if cmd in ['create', 'edit']:
        rel_args = dict(
            name=args.name,
            body=args.body,
            commitish=args.commitish,
            draft=args.draft,
            prerelease=args.prerelease,
        )
    if cmd == "create":
        result = rm.create_release(
            tag=args.tag,
            **rel_args
        )
    elif cmd == "edit":
        if args.release_id:
            result = rm.edit_release(
                args.release_id,
                **rel_args
            )
        else:
            result = rm.edit_release_by_tag(
                args.tag,
                new_tag=args.switch_tag_to,
                **rel_args
            )
    elif cmd == "delete":
        if args.release_id:
            result = rm.delete_release(args.release_id)
        else:
            result = rm.delete_release_by_tag(args.tag)
    elif cmd == "upload-asset":
        upload = rm.replace_asset if args.replace else rm.upload_asset
        if len(args.asset_paths) == 1:
            result = upload(
                asset_path=args.asset_paths[0],
                tag=args.tag,
                rel_id=args.release_id,
                asset_name=args.name,
                asset_label=args.label)
        else:
            if args.name or args.label:
                log.warning(
                    "Asset name/label options ignored for multiple files"
                )
            # Remove any duplicates
            paths = set(args.asset_paths)
            success = True
            acc_responses = []
            for p in paths:
                ok, response = upload(
                    asset_path=p,
                    tag=args.tag,
                    rel_id=args.release_id
                )
                success = success and ok
                acc_responses.append(response)
            result = success, acc_responses
        if args.max_assets:
            success, responses = rm.delete_oldest_assets(
                max_assets=args.max_assets,
                rel_id=args.release_id,
                tag=args.tag
            )
            result = result[0] and success, (result[1], responses)
    elif cmd == "edit-asset":
        result = rm.edit_asset(
            args.asset_id, new_name=args.name, new_label=args.label
        )
    elif cmd == "delete-asset":
        result = rm.delete_asset(args.asset_id)
    else:
        raise NotImplementedError("Command not implemented:", cmd)
    return result


if __name__ == '__main__':
    exit(not main()[0])
