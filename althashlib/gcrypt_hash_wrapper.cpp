#include "gcrypt_hash_wrapper.hpp"
#include <Python.h>
#include <gcrypt.h>

static bool initialized = false;

Hasher::Hasher(int hash_type) : hash_type(hash_type) {\
  active_handle = &handle1;
  inactive_handle = &handle2;
  // Initialize libgcrypt
  if (!initialized) {
    gcry_check_version(NULL);
    initialized = true;
  }
  // Verify that the hash type index is valid
  gcry_error_t err = gcry_md_test_algo(hash_type);
  if (err) {
    throw err;
  }
  // Set up the handle for the given hash type
  digest_size_v = gcry_md_get_algo_dlen(hash_type);
  err = gcry_md_open(active_handle, hash_type, 0);
  if (err) {
    throw err;
  }
}

Hasher::~Hasher() {
  if (*active_handle) {
    gcry_md_close(*active_handle);
  }
}

uint Hasher::digest_size() {
  return digest_size_v;
}

void Hasher::update(char* data, int size)
{
  gcry_md_write(*active_handle, data, size);
}

PyObject* Hasher::digest()
{
   // Copy the active handle to the inactive handle
    gcry_md_copy(inactive_handle, *active_handle);
    // Get the digest - finalizes the active handle, invalidating further ops
    const unsigned char* result = gcry_md_read(*active_handle, hash_type);
    // Copy digest to python string
    PyObject* ret = PyString_FromStringAndSize((const char*)result, digest_size_v);
    // Close the handle (might not be necessary in this case)
    gcry_md_close(*active_handle);
    // Swap the active and inactive states
    gcry_md_hd_t* tmp = active_handle;
    active_handle = inactive_handle;
    inactive_handle = tmp;

    return ret;
}
