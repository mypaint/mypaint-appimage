#!/bin/bash

# Bundle the python runtime
PYTHON_PREFIX=$(pkg-config --variable=prefix python)
PYTHON_LIBDIR=$(pkg-config --variable=libdir python)
PYTHON_VERSION=$(pkg-config --modversion python)
if [ -z "${PYTHON_PREFIX}" ]; then
    echo "Could not determine PYTHON installation prefix, exiting."
    exit 1
fi
if [ -z "${PYTHON_LIBDIR}" ]; then
    echo "Could not determine PYTHON library path, exiting."
    exit 1
fi
if [ -z "${PYTHON_VERSION}" ]; then
    echo "Could not determine PYTHON version, exiting."
    exit 1
fi

set -e

cp -a "${PYTHON_PREFIX}/bin"/python* "$APPDIR/usr/bin"
rm -rf "$APPDIR/usr/lib/python${PYTHON_VERSION}"
mkdir -p "$APPDIR/usr/lib"
cp -a "${PYTHON_LIBDIR}/python${PYTHON_VERSION}" "$APPDIR/usr/lib"

PYGLIB_LIBDIR=$(pkg-config --variable=libdir pygobject-2.0 || true)
if [ x"${PYGLIB_LIBDIR}" != "x" ]; then
    cp -a "${PYGLIB_LIBDIR}"/libpyglib*.so* "$APPDIR/usr/lib"
else
    echo "Could not determine PYGOBJECT-2.0 library path."
fi

mkdir -p "$APPDIR/usr/lib64"
cd "$APPDIR/usr/lib64"
rm -rf python"${PYTHON_VERSION}"
ln -s ../lib/python"${PYTHON_VERSION}" .
cd -

# Prepare the hashlib replacement - to remove a bunch of dependencies unique to the regular hashlib
HLIB_FOLDER="$APPIM_SOURCES/althashlib/"
GCR_WRAPPER=gcrypt_hash_wrapper
cd $HLIB_FOLDER
python setup.py build_ext --inplace
pyminify --remove-literal-statements althashlib.py > hashlib.py
pyminify --remove-literal-statements $GCR_WRAPPER.py > tmp && mv tmp $GCR_WRAPPER.py

# Remove some stuff we don't need

cd "$APPDIR/usr/lib/python${PYTHON_VERSION}/"

# This list is determined by the absence of corresponding *.pyc files, and will need to be updated when additional
# dependencies are added, directly or indirectly. Just starting the program is not enough to trigger compilation
# of all dependencies - the full functionality must be used in order to be sure.
rm -rf aifc.py antigravity.py anydbm.py ast.py asynchat.py asyncore.py audiodev.py BaseHTTPServer.py \
   Bastion.py bdb.py binhex.py bsddb calendar.py CGIHTTPServer.py cgi.py cgitb.py chunk.py cmd.py codeop.py \
   code.py commands.py compileall.py compiler config cookielib.py Cookie.py crypt.py csv.py curses dbhash.py \
   decimal.py dircache.py distutils doctest.py DocXMLRPCServer.py dumbdbm.py dummy_threading.py dummy_thread.py email \
   filecmp.py fileinput.py formatter.py fpformat.py fractions.py ftplib.py getopt.py getpass.py gzip.py hmac.py hotshot \
   htmlentitydefs.py htmllib.py HTMLParser.py httplib.py idlelib ihooks.py imaplib.py imghdr.py imputil.py lib2to3 \
   _LWPCookieJar.py macpath.py macurl2path.py mailbox.py mailcap.py markupbase.py md5.py mhlib.py mimetools.py \
   mimetypes.py MimeWriter.py mimify.py modulefinder.py _MozillaCookieJar.py multifile.py multiprocessing mutex.py \
   netrc.py new.py nntplib.py ntpath.py nturl2path.py numbers.py os2emxpath.py _osx_support.py pdb.py __phello__.foo.py \
   pickletools.py pipes.py plat-linux2 plistlib.py popen2.py poplib.py posixfile.py profile.py pty.py pyclbr.py \
   py_compile.py pydoc_data _pyio.py Queue.py quopri.py rexec.py rfc822.py rlcompleter.py robotparser.py runpy.py \
   sched.py sets.py sgmllib.py sha.py shelve.py SimpleHTTPServer.py SimpleXMLRPCServer.py smtpd.py \
   smtplib.py sndhdr.py SocketServer.py sqlite3 sre.py statvfs.py stringold.py stringprep.py _strptime.py sunaudio.py \
   sunau.py symbol.py symtable.py tabnanny.py tarfile.py telnetlib.py test this.py _threading_local.py timeit.py \
   toaiff.py trace.py tty.py urllib2.py UserList.py user.py UserString.py uu.py wave.py whichdb.py \
   wsgiref xdrlib.py xmllib.py xmlrpclib.py ctypes

# Replace the regular hashlib with our alternative smaller version

mv $HLIB_FOLDER/hashlib.py .
mv $HLIB_FOLDER/_$GCR_WRAPPER*so $HLIB_FOLDER/$GCR_WRAPPER.py .

# These encodings should not be necessary for the linux-only appimage
(cd encodings && rm -rf iso* cp* mac_*)

# Determined by scripted trial and error. Some of these may need to be reinstated for performance reasons (if they are used).
(cd lib-dynload &&
        rm -rf arraymodule.so audioop.so _bisectmodule.so _bsddb.so bz2.so cmathmodule.so _cryptmodule.so _csv.so _ctypes.so \
           _curses_panel.so _curses.so dbm.so dlmodule.so future_builtins.so gdbmmodule.so grpmodule.so _heapq.so _hotshot.so \
           imageop.so _json.so linuxaudiodev.so _lsprof.so mmapmodule.so _multibytecodecmodule.so _multiprocessing.so \
           nismodule.so ossaudiodev.so parsermodule.so readline.so resource.so spwdmodule.so _sqlite3.so _ssl.so stropmodule.so \
           syslog.so termios.so timingmodule.so xxsubtype.so _hashlib.so
)

# Clear a bunch of modules that are currently not used - if/when integration tests
# covering 100% of the mypaint modules are added, finding these modules can be easily
# automated by running the integration tests on the prepared appimage files, and checking
# which .py modules were not compiled to .pyc afterwards.
(
pref=$APPIM_SOURCES/scripts/helpers
for f in $(cat $pref/"unimported")
do
    rm -f $f
done
)

cd site-packages
# Some unused selinux stuff added after an update of the docker image
rm -rf audit.py _audit.so auparse.so policycoreutils sepolicy sepolgen seobject semanage.py _semanage.so selinux
rm -rf gpgme  markupsafe OpenSSL pycurl.so pygtkcompat rpm sqlitecachec.py _sqlitecache.so xattr.so

cd numpy
rm -rf doc distutils oldnumeric
rm -f ./linalg/lapack_lite.so && touch ./linalg/lapack_lite.py
rm -f ./core/_dotblas.so && touch ./core/_dotblas.py

cd core
rm -rf lib include umath_tests.so multiarray_tests.so

# This can only be removed if the import is removed from numpy/core/__init__.py
# (and if it isn't used by MyPaint, of course)
rm -f scalarmath.so
cd ..

# Imports of these otherwise unused modules removed must be
# explicitly removed in the main numpy __init__.py file.
# This is done in the docker image that the appimage is built on.
rm -rf random ma fft add_newdocs.py

echo "Python bundling finished"
