{
    description             = "openapi2jsonschema";
    inputs.nixpkgs.url      = "github:NixOS/nixpkgs";
    inputs.flake-utils.url  = "github:numtide/flake-utils";

    outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem
    [
        "x86_64-darwin" 
        "aarch64-darwin"
        "x86_64-linux" 
        "aarch64-linux"
    ]
    (system:
    
    let
        pkgs                   = nixpkgs.legacyPackages.${system};
        openapi2jsonschemaDeps = pythonPkgs: with pythonPkgs; [ pyyaml jsonref click ];
        version                = "1.0.1";
        pname                  = "openapi2jsonschema";
        openapi2jsonschema     = pythonPkgs:
        [
            (
                pythonPkgs.buildPythonPackage rec
                {
                    inherit pname version;
                    src                   = ./.;
                    doCheck               = true;
                    nativeCheckInputs     = with pythonPkgs; [ pytest ];
                    propagatedBuildInputs = openapi2jsonschemaDeps pythonPkgs;

                    postInstall = 
                    ''
                        ln -s $out/bin/command.py $out/bin/openapi2jsonschema
                    '';
                }
            )
        ];

        openapi2jsonschema-drv = pkgs.python3.withPackages openapi2jsonschema;
        openapi2jsonschema-image = pkgs: pkgs.dockerTools.streamLayeredImage
        {
            name     = pname;
            tag      = version;
            config   = 
            { 
                Entrypoint = [ "${openapi2jsonschema-drv}/bin/openapi2jsonschema" ];
                Cmd        = [ "--help" ]; 
            };
        };

        pushContainerToRegistry = { streamLayeredImage, registry, registryUser, registryPassword }: 
        pkgs.writeShellApplication
        {
            name          = "pushToRegistry.sh";
            runtimeInputs = with pkgs; [ gzip skopeo bash ];
            text          = 
            ''
                 ${streamLayeredImage} | gzip --fast | skopeo copy docker-archive:/dev/stdin docker://${registry} \
                    --dest-creds ${registryUser}:${registryPassword} --insecure-policy
            '';
        };

        createMultiArchManifest = { registryImage, tag, registryUser, registryPassword }: 
        pkgs.writeShellApplication
        {
            name          = "createMultiArchManifest.sh";
            runtimeInputs = with pkgs; [ manifest-tool ];
            text          = 
            ''
                manifest-tool --username ${registryUser} --password ${registryPassword} push from-args \
                    --platforms linux/amd64,linux/arm64 \
                    --template ${registryImage}-ARCH:${tag} \
                    --target ${registryImage}:${tag}
            '';
        };
        
        retagImage = { registry, imageUrl, newTag, registryUser, registryPassword }: 
        pkgs.writeShellApplication
        {
            name          = "retagImage.sh";
            runtimeInputs = with pkgs; [ crane ];
            text          = 
            ''
                crane auth login -u ${registryUser} -p ${registryPassword} ${registry}
                crane tag ${imageUrl} ${newTag}
            '';
        };

    in
    {
        packages = 
        {
            default = openapi2jsonschema-drv;
            openapi2jsonschema-image-amd64 = openapi2jsonschema-image pkgs.pkgsStatic;
            openapi2jsonschema-image-arm64 = openapi2jsonschema-image pkgs.pkgsCross.aarch64-multiplatform-musl.pkgsStatic;
        };

        apps =
        let registryUser     = ''"$CI_REGISTRY_USER"'';
            registryPassword = ''"$CI_REGISTRY_PASSWORD"'';
            registry         = ''"$CI_REGISTRY"'';
            registryImage    = ''"$CI_REGISTRY_IMAGE"/openapi2jsonschema'';
        in
        {
            push-amd64-image-to-registry = 
            { 
                type = "app"; 
                program = "${pushContainerToRegistry 
                { 
                    streamLayeredImage = self.packages.${system}.openapi2jsonschema-image-amd64;
                    registry = "${registryImage}-amd64:${version}";
                    inherit registryUser registryPassword;
                }}/bin/pushToRegistry.sh"; 
            };
            
            push-arm64-image-to-registry = 
            { 
                type = "app"; 
                program = "${pushContainerToRegistry 
                { 
                    streamLayeredImage = self.packages.${system}.openapi2jsonschema-image-arm64;
                    registry = "${registryImage}-arm64:${version}";
                    inherit registryUser registryPassword;
                }}/bin/pushToRegistry.sh"; 
            };

            create-multi-arch-manifest = 
            { 
                type = "app"; 
                program = "${createMultiArchManifest 
                {
                    inherit registryUser registryPassword registryImage;
                    tag = version;
                }}/bin/createMultiArchManifest.sh"; 
            };

            retag-image = 
            { 
                type = "app"; 
                program = "${retagImage 
                {
                    inherit registryUser registryPassword registry;
                    imageUrl = "${registryImage}:${version}";
                    newTag = "latest";
                }}/bin/retagImage.sh"; 
            };

            default = self.apps.${system}.push-amd64-image-to-registry;
        };

        devShells.default = pkgs.mkShell 
        {
            packages = with pkgs;
            [
                (python3.withPackages (pythonPkgs: openapi2jsonschemaDeps pythonPkgs))
            ];
        };
    });
}
