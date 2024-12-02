{ fetchFromGitLab, fuse, perl, readline, stdenv }:

stdenv.mkDerivation rec {
  pname = "uml-utilities";
  version = "20070815.4";

  src = fetchFromGitLab {
    owner = "uml-team";
    repo = "uml-utilities";
    domain = "salsa.debian.org";
    rev = "90d7bbdbc8eeeb9a92fc10038d2b64e7b90cd601";
    hash = "sha256-NFtZcceUKI7PJRzY4vwLYbNGNvnqEHv7CyA2TOeyyAI=";
  };

  buildInputs = [
    fuse
    perl
    readline
  ];

  makeFlags = [ "BIN_DIR=$(out)/bin" "LIB_DIR=$(lib)/lib/uml" "SBIN_DIR=$(out)/bin" ];

  outputs = [ "out" "lib" ];

  patches = [ ./install-fix.patch ];
}
