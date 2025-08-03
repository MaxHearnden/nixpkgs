{
  lib,
  stdenv,
  fetchFromGitHub,
  nixosTests,
}:

stdenv.mkDerivation (finalAttrs: {
  version = "0.9.5";
  pname = "tayga";

  src = fetchFromGitHub {
    owner = "apalrd";
    repo = finalAttrs.pname;
    tag = finalAttrs.version;
    hash = "sha256-xOm4fetFq2UGuhOojrT8WOcX78c6MLTMVbDv+O62x2E=";
  };

  installPhase = ''
    runHook preInstall

    install -Dm755 tayga -t $out/bin
    install -Dm644 tayga.8 -t $out/share/man/man8
    install -Dm644 tayga.conf.5 -t $out/share/man/man5

    runHook postInstall
  '';

  passthru.tests.tayga = nixosTests.tayga;

  meta = with lib; {
    description = "Userland stateless NAT64 daemon";
    longDescription = ''
      TAYGA is an out-of-kernel stateless NAT64 implementation
      for Linux that uses the TUN driver to exchange IPv4 and
      IPv6 packets with the kernel.
      It is intended to provide production-quality NAT64 service
      for networks where dedicated NAT64 hardware would be overkill.
    '';
    homepage = "https://github.com/apalrd/tayga";
    license = licenses.gpl2Plus;
    maintainers = with maintainers; [ _0x4A6F ];
    platforms = platforms.linux;
    mainProgram = "tayga";
  };
})
