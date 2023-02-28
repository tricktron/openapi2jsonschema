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
            openapi2jsonschema-image = openapi2jsonschema-image pkgs;
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
