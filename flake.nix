{
    description             = "openapi2jsonschema-dev-shell";
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
        pkgs = nixpkgs.legacyPackages.${system};
    in
    {
        devShells.default = pkgs.mkShell 
        {
            packages = with pkgs;
            [
                (python3.withPackages (ps: with ps; [ pyyaml jsonref click ]))
            ];
        };
    });
}
