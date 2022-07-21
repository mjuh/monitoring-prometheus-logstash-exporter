{
  description = "logstash prometheus exporter";

  outputs = { self, nixpkgs, ... }:
    let system = "x86_64-linux";
    in {
      packages.${system} = {
        default = nixpkgs.legacyPackages.${system}.callPackage
          ({ lib, go, buildGoModule }:
            buildGoModule rec {
              pname = "logstash-exporter";
              version = "0.0.1";
              src = ./.;
              # preConfigure phase to compile a statically linked executable
              preConfigure = ''
                export CGO_ENABLED=0
                export GOOS=linux
                export GOARCH=amd64
              '';
              ldflags = let t = "github.com/prometheus/common/version";
              in [
                "-s" # stripped binary
                "-X ${t}.Version=${version}"
                "-X ${t}.Branch=unknown"
                "-X ${t}.BuildUser=nix@nixpkgs"
                "-X ${t}.BuildDate=unknown"
                "-X ${t}.GoVersion=${lib.getVersion go}"
              ];
              vendorSha256 =
                "sha256-A8olavmxLDW1SMgp2Jzr9tTXv6Qwg4UINVMYDLUF0vk=";
              meta = with lib; {
                description = "Prometheus Logstash metrics.";
                homepage = "https://github.com/alxrem/prometheus-logstash-exporter";
                license = licenses.asl20;
                platforms = platforms.unix;
              };
            }) { };
      };
    };
}
