// Copyright (c) 2022, Google Inc.
// SPDX-License-Identifier: ISC
// Modifications copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
// SPDX-License-Identifier: Apache-2.0 OR ISC
//
// Simplified version of aws-lc-sys's rust_wrapper.h for use with
// rust_bindgen + cargo_build_info. See the original at:
// https://github.com/aws/aws-lc-rs/blob/main/aws-lc-sys/include/rust_wrapper.h

#ifndef OPENSSL_HEADER_RUST_WRAPPER_H
#define OPENSSL_HEADER_RUST_WRAPPER_H

#include <openssl/aes.h>
#include <openssl/asn1.h>
#include <openssl/asn1t.h>
#include <openssl/base.h>
#include <openssl/base64.h>
#include <openssl/bio.h>
#include <openssl/bn.h>
#include <openssl/buf.h>
#include <openssl/bytestring.h>
#include <openssl/chacha.h>
#include <openssl/cipher.h>
#include <openssl/cmac.h>
#include <openssl/conf.h>
#include <openssl/cpu.h>
#include <openssl/crypto.h>
#include <openssl/curve25519.h>
#include <openssl/des.h>
#include <openssl/dh.h>
#include <openssl/digest.h>
#include <openssl/dsa.h>
#include <openssl/ec.h>
#include <openssl/ec_key.h>
#include <openssl/ecdh.h>
#include <openssl/ecdsa.h>
#include <openssl/engine.h>
#include <openssl/err.h>
#include <openssl/evp.h>
#include <openssl/ex_data.h>
#include <openssl/hkdf.h>
#include <openssl/hmac.h>
#include <openssl/hpke.h>
#include <openssl/hrss.h>
#include <openssl/mem.h>
#include <openssl/obj.h>
#include <openssl/objects.h>
#include <openssl/opensslconf.h>
#include <openssl/pem.h>
#include <openssl/pkcs7.h>
#include <openssl/pkcs8.h>
#include <openssl/poly1305.h>
#include <openssl/pool.h>
#include <openssl/rand.h>
#include <openssl/rsa.h>
#include <openssl/sha.h>
#include <openssl/stack.h>
#include <openssl/thread.h>
#include <openssl/trust_token.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>

#endif // OPENSSL_HEADER_RUST_WRAPPER_H
