#include <openssl/evp.h>
#include <openssl/crypto.h>

#include <errno.h>
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

enum {
    EXIT_USAGE = 64,
    EXIT_INPUT = 65,
    EXIT_VERIFY = 66,
    ED448_PUBLIC_KEY_BYTES = 57,
    MAX_SIGNATURE_BYTES = 256,
    MAX_MESSAGE_BYTES = 8192
};

static int open_regular_readonly(const char *path, size_t maximum_bytes, struct stat *metadata) {
    int descriptor = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK);
    if (descriptor < 0) {
        return -1;
    }
    if (fstat(descriptor, metadata) != 0 || !S_ISREG(metadata->st_mode) ||
        metadata->st_nlink != 1 || metadata->st_size < 0 ||
        (uint64_t)metadata->st_size > (uint64_t)maximum_bytes) {
        close(descriptor);
        errno = EINVAL;
        return -1;
    }
    return descriptor;
}

static int metadata_unchanged(const struct stat *before, const struct stat *after) {
    return before->st_dev == after->st_dev &&
        before->st_ino == after->st_ino &&
        before->st_mode == after->st_mode &&
        before->st_nlink == after->st_nlink &&
        before->st_uid == after->st_uid &&
        before->st_gid == after->st_gid &&
        before->st_size == after->st_size &&
        before->st_mtimespec.tv_sec == after->st_mtimespec.tv_sec &&
        before->st_mtimespec.tv_nsec == after->st_mtimespec.tv_nsec &&
        before->st_ctimespec.tv_sec == after->st_ctimespec.tv_sec &&
        before->st_ctimespec.tv_nsec == after->st_ctimespec.tv_nsec;
}

static unsigned char *read_bounded_file(const char *path, size_t maximum_bytes, size_t *length) {
    struct stat metadata;
    int descriptor = open_regular_readonly(path, maximum_bytes, &metadata);
    if (descriptor < 0) {
        return NULL;
    }

    size_t expected = (size_t)metadata.st_size;
    unsigned char *bytes = malloc(expected == 0 ? 1 : expected);
    if (bytes == NULL) {
        close(descriptor);
        return NULL;
    }

    size_t offset = 0;
    while (offset < expected) {
        ssize_t count = read(descriptor, bytes + offset, expected - offset);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0) {
            free(bytes);
            close(descriptor);
            return NULL;
        }
        offset += (size_t)count;
    }
    struct stat after;
    if (fstat(descriptor, &after) != 0 || !metadata_unchanged(&metadata, &after)) {
        free(bytes);
        close(descriptor);
        errno = EAGAIN;
        return NULL;
    }
    close(descriptor);
    *length = expected;
    return bytes;
}

static int nibble(char value) {
    if (value >= '0' && value <= '9') return value - '0';
    if (value >= 'a' && value <= 'f') return value - 'a' + 10;
    if (value >= 'A' && value <= 'F') return value - 'A' + 10;
    return -1;
}

static int decode_hex_exact(const char *hex, unsigned char *bytes, size_t byte_count) {
    if (strlen(hex) != byte_count * 2) return 0;
    for (size_t index = 0; index < byte_count; ++index) {
        int high = nibble(hex[index * 2]);
        int low = nibble(hex[index * 2 + 1]);
        if (high < 0 || low < 0) return 0;
        bytes[index] = (unsigned char)((high << 4) | low);
    }
    return 1;
}

static int sha3_256_file(const char *path) {
    struct stat metadata;
    int descriptor = open_regular_readonly(path, 600000000, &metadata);
    if (descriptor < 0) return EXIT_INPUT;

    EVP_MD_CTX *context = EVP_MD_CTX_new();
    if (context == NULL || EVP_DigestInit_ex(context, EVP_sha3_256(), NULL) != 1) {
        close(descriptor);
        EVP_MD_CTX_free(context);
        return EXIT_VERIFY;
    }

    unsigned char buffer[1024 * 1024];
    off_t remaining = metadata.st_size;
    while (remaining > 0) {
        size_t requested = (uint64_t)remaining < sizeof(buffer) ? (size_t)remaining : sizeof(buffer);
        ssize_t count = read(descriptor, buffer, requested);
        if (count < 0 && errno == EINTR) continue;
        if (count <= 0 || EVP_DigestUpdate(context, buffer, (size_t)count) != 1) {
            close(descriptor);
            EVP_MD_CTX_free(context);
            return EXIT_INPUT;
        }
        remaining -= count;
    }
    struct stat after;
    if (fstat(descriptor, &after) != 0 || !metadata_unchanged(&metadata, &after)) {
        close(descriptor);
        EVP_MD_CTX_free(context);
        return EXIT_INPUT;
    }
    close(descriptor);

    unsigned char digest[EVP_MAX_MD_SIZE];
    unsigned int digest_length = 0;
    int ok = EVP_DigestFinal_ex(context, digest, &digest_length);
    EVP_MD_CTX_free(context);
    if (ok != 1 || digest_length != 32) return EXIT_VERIFY;

    for (unsigned int index = 0; index < digest_length; ++index) {
        printf("%02x", digest[index]);
    }
    putchar('\n');
    return 0;
}

static int verify_ed448(const char *public_key_hex, const char *signature_path,
                        const char *message_path) {
    unsigned char public_key[ED448_PUBLIC_KEY_BYTES];
    if (!decode_hex_exact(public_key_hex, public_key, sizeof(public_key))) return EXIT_INPUT;

    size_t signature_length = 0;
    size_t message_length = 0;
    unsigned char *signature = read_bounded_file(signature_path, MAX_SIGNATURE_BYTES, &signature_length);
    unsigned char *message = read_bounded_file(message_path, MAX_MESSAGE_BYTES, &message_length);
    if (signature == NULL || message == NULL) {
        free(signature);
        free(message);
        return EXIT_INPUT;
    }

    EVP_PKEY *key = EVP_PKEY_new_raw_public_key(
        EVP_PKEY_ED448, NULL, public_key, sizeof(public_key)
    );
    EVP_MD_CTX *context = EVP_MD_CTX_new();
    int valid = key != NULL && context != NULL &&
        EVP_DigestVerifyInit(context, NULL, NULL, NULL, key) == 1 &&
        EVP_DigestVerify(context, signature, signature_length, message, message_length) == 1;

    EVP_MD_CTX_free(context);
    EVP_PKEY_free(key);
    free(signature);
    free(message);
    return valid ? 0 : EXIT_VERIFY;
}

int main(int argc, char **argv) {
    /* This verifier has no configuration or provider-extension surface. Call
       before every other OpenSSL API so caller-controlled OPENSSL_CONF and
       OPENSSL_MODULES values cannot affect verification behavior. */
    if (OPENSSL_init_crypto(OPENSSL_INIT_NO_LOAD_CONFIG, NULL) != 1) {
        return EXIT_VERIFY;
    }
    if (argc == 3 && strcmp(argv[1], "sha3-256") == 0) {
        return sha3_256_file(argv[2]);
    }
    if (argc == 5 && strcmp(argv[1], "verify-ed448") == 0) {
        return verify_ed448(argv[2], argv[3], argv[4]);
    }
    fprintf(stderr, "Usage: QuilNodeReleaseVerifier sha3-256 <file> | verify-ed448 <public-key-hex> <signature> <message>\n");
    return EXIT_USAGE;
}
