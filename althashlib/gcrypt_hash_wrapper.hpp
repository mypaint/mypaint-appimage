#ifndef GCRYPTHASHWRAPPERHPP
#define GCRYPTHASHWRAPPERHPP

#include <Python.h>
#include <gcrypt.h>

#define GCRYPT_NO_DEPRECATED

// THe subset of algorithms in libgcrypt with implementations
// (and that are available in the particular version of libgcrypt
// that this wrapper supports)
const int SHA1 = GCRY_MD_SHA1;
const int RMD160 = GCRY_MD_RMD160;
const int MD5 = GCRY_MD_MD5;
const int MD4 = GCRY_MD_MD4;
const int SHA224 = GCRY_MD_SHA224;
const int SHA256 = GCRY_MD_SHA256;
const int SHA384 = GCRY_MD_SHA384;
const int SHA512 = GCRY_MD_SHA512;
const int WHIRLPOOL = GCRY_MD_WHIRLPOOL;

// Could be exposed, but won't be
// const int TIGER = GCRY_MD_TIGER;
// const int TIGER1 = GCRY_MD_TIGER1;
// const int TIGER2 = GCRY_MD_TIGER2;
// const int GOSTR3411_94 = GCRY_MD_GOSTR3411_94;
// const int STRIBOG256 = GCRY_MD_STRIBOG256;
// const int STRIBOG512 = GCRY_MD_STRIBOG512;
// const int CRC32 = GCRY_MD_CRC32;
// const int CRC32_RFC1510 = GCRY_MD_CRC32_RFC1510;
// const int CRC24_RFC2440 = GCRY_MD_CRC24_RFC2440;

/**
 * Provides a minimal subset of functionality required
 * to conform to hashlib's API.
 *
 */
class Hasher
{
public:
  explicit Hasher(int hash_type);
  ~Hasher();
  uint digest_size();
  void update(char *data, int size);
  PyObject* digest();

private:
  int hash_type;
  int digest_size_v;
  // Up to two handles are stored, to allow access to the digest between
  // calls to ``update``. Only one of them is active at at any one time.
  gcry_md_hd_t handle1;
  gcry_md_hd_t handle2;
  gcry_md_hd_t* active_handle;
  gcry_md_hd_t* inactive_handle;
};

#endif // include guard
