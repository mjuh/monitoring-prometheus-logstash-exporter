{
  description = "logstash prometheus exporter";

  outputs = { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      inherit (pkgs) callPackage;
    in {
      packages.${system} = rec {
        default = callPackage
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

        container = callPackage
          ({ dockerTools
           , locale
           , tzdata
           , prometheus-logstash-exporter }:
             dockerTools.buildLayeredImage {
               name = "docker-registry.intr/monitoring/prometheus-logstash-exporter";
               tag = "master";
               contents = [
                 locale
                 tzdata
                 prometheus-logstash-exporter
               ];
               config = {
                 Env = [
                   "TZDIR=${tzdata}/share/zoneinfo"
                   "LOCALE_ARCHIVE=${locale}/lib/locale/locale-archive"
                 ];
                 Entrypoint = [ "/bin/prometheus-logstash-exporter" ];
               };
             })
          {
            prometheus-logstash-exporter = default;
          };
      };

      apps.${system} = {
        container-structure-test = let
          inherit (pkgs) runtimeShell writeScriptBin;
          config = let
            inherit (builtins) toJSON;
            inherit (pkgs) writeText;
          in writeText "container-structure-test.yaml" (toJSON {
            fileExistenceTests = [
              {
                name = "root";
                path = "/";
                shouldExist = true;
              }
              {
                name = "prometheus-logstash-exporter";
                path = "/bin/prometheus-logstash-exporter";
                shouldExist = true;
              }
            ];
            schemaVersion = "2.0.0";
          });
          script = writeScriptBin "container-structure-test" ''
            #!${runtimeShell} -e
            docker run --volume /var/run/docker.sock:/var/run/docker.sock \
                       --volume ${config}:/container-structure-test.yaml \
                       gcr.io/gcp-runtimes/container-structure-test:latest \
                       test --image docker-registry.intr/monitoring/prometheus-logstash-exporter:master \
                            --config container-structure-test.yaml
         '';
        in {
          type = "app";
          program = "${script}/bin/container-structure-test";
        };
      };
    };
}
