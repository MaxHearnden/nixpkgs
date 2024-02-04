{ fetchFromGitLab, fetchurl, fuse, lib, readline, stdenv, perl }:

stdenv.mkDerivation {
  pname = "uml-utilities";
  version = "20070815";

  src = fetchFromGitLab {
    domain = "salsa.debian.org";
    owner = "uml-team";
    repo = "uml-utilities";
    rev = "a816d5d4a9e912e1a79ff0fa5cdce6e6e2a19cc3";
    hash = "sha256-c5gwukIhjycM1/J/sSz3EDhtjSXTxw1a88QlzfjtkH4=";
  };

  buildInputs = [
    fuse
    readline
    perl
  ];

  patches = [
    ./install-fix.patch
  ];

  makeFlags = [ "BIN_DIR=$(out)/bin" "LIB_DIR=$(out)/lib" "SBIN_DIR=$(out)/bin" ];

  meta = with lib; {
    description = "A collection of programs for use with user-mode linux";
    homepage = "https://user-mode-linux.sourceforge.net/";
    maintainers = [ maintainers.maxhearnden ];
    license = licenses.gpl2;
    platforms = platforms.linux;
  };
}
