# mini.ai + mini.surround, default mappings. Keep `search_method` and `n_lines` the same in both.
{ nvimPkgs, ... }:
{
  programs.nixvim = {
    # only for `gen_ai_spec.indent` below; needs no setup
    extraPlugins = with nvimPkgs.vimPlugins; [ mini-extra ];

    plugins.mini-ai = {
      enable = true;

      settings = {
        # the default, 50, gives up inside a long function
        n_lines = 500;

        custom_textobjects = {
          # indent scope on `i`: cii / cai, plus mini.ai's next/last variants
          i.__raw = ''require("mini.extra").gen_ai_spec.indent()'';
        };
      };
    };

    plugins.mini-surround = {
      enable = true;

      # matches mini.ai (the default is 20)
      settings = {
        n_lines = 500;
      };
    };
  };
}
