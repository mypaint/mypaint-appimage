# The schmall incomplete hashlib backed by libgcrypt

import gcrypt_hash_wrapper as ghw

algorithms_available = {
    'SHA256', 'sha256',
    'SHA224', 'sha224',
    'SHA384', 'sha384',
    'SHA512', 'sha512',
    'SHA', 'sha', 'SHA1', 'sha1',
    'md4', 'MD4', 'md5', 'MD5',
    'whirlpool',
    'RIPEMD160', 'ripemd160',
}

_algo_map = {
    'SHA256': ghw.SHA256,
    'sha256': ghw.SHA256,
    'SHA224': ghw.SHA224,
    'sha224': ghw.SHA224,
    'SHA384': ghw.SHA384,
    'sha384': ghw.SHA384,
    'SHA512': ghw.SHA512,
    'sha512': ghw.SHA512,
    'SHA': ghw.SHA1,
    'sha': ghw.SHA1,
    'SHA1': ghw.SHA1,
    'sha1': ghw.SHA1,
    'md4': ghw.MD4,
    'MD4': ghw.MD4,
    'md5': ghw.MD5,
    'MD5': ghw.MD5,
    'whirlpool': ghw.WHIRLPOOL,
    'RIPEMD160': ghw.RMD160,
    'ripemd160': ghw.RMD160,
}


class GenericHash (object):

    def __init__(self, name, data=None):
        algo = _algo_map.get(name, ghw.SHA1)
        self.hasher = ghw.Hasher(algo)
        self.block_size = None  # Assumption: not necessary for this use case
        if data:
            self.update(data)

    def update(self, data):
        return self.hasher.update(data)

    def copy(self):
        raise NotImplementedError

    @property
    def digest_size(self):
        return self.hasher.digest_size()

    def digest(self):
        return self.hasher.digest()

    def hexdigest(self):
        return self.hasher.digest().encode('hex')


def new(name, data=None):
    return GenericHash(name, data)


def md5(data=None):
    return GenericHash('md5', data)


def sha1(data=None):
    return GenericHash('sha1', data)


def sha224(data=None):
    return GenericHash('sha224', data)


def sha256(data=None):
    return GenericHash('sha256', data)


def sha384(data=None):
    return GenericHash('sha384', data)


def sha512(data=None):
    return GenericHash('sha512', data)
