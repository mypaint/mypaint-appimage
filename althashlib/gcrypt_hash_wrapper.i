%module gcrypt_hash_wrapper;

%apply (char *STRING, int LENGTH) { (char *data, int size) };

%{
#include "gcrypt_hash_wrapper.hpp"
%}


%include "gcrypt_hash_wrapper.hpp"
