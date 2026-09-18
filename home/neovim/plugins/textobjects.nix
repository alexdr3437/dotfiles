# mini.ai + mini.surround: the two halves of "operate on a delimited region".
#
# Grouped in one file because they are the same idea and share mini's search
# engine -- `search_method` and `n_lines` mean the same thing in both, and a
# change to one that is not mirrored in the other is almost always a bug.
#
# Split packages again, not the mini.nvim bundle, matching minimap.nix.
#
# Both keep their upstream default mappings:
#   mini.ai        a / i, plus the an/in (next) and al/il (last) variants,
#                  and g[ / g] to jump to a target's edges. Adds objects the
#                  builtins lack: `a` argument, `f` function call, `t` tag,
#                  `?` prompt-for-delimiters, and `i` indent (see below).
#   mini.surround  sa add, sd delete, sr replace, sf/sF find, sh highlight,
#                  sn update n_lines.
{ nvimPkgs, ... }:
{
  programs.nixvim = {
    # Carried only for `gen_ai_spec.indent` below. mini.extra is never set up:
    # the generators hang off the module table itself, so having the plugin on
    # the runtimepath is all `require("mini.extra")` needs.
    extraPlugins = with nvimPkgs.vimPlugins; [ mini-extra ];

    plugins.mini-ai = {
      enable = true;

      settings = {
        # 50 (the default) is a screenful. The point of mini.ai over the builtin
        # text objects is that it finds a pair that starts well above or ends
        # well below the cursor, which 50 gives up on inside any real function.
        n_lines = 500;

        custom_textobjects = {
          # Indent scope on `i`, so cii / cai sit next to cia / caa instead of
          # arriving as a separate plugin with its own hardcoded `ii` mapping.
          # Routing it through mini.ai is the whole point: the variants come
          # free -- cini / cili for the next and last scope, vii to select,
          # g[i / g]i to jump to an edge -- and none of that exists in
          # vim-indent-object and friends.
          #
          # A scope is the run of lines indented strictly deeper than the two
          # non-blank lines bracketing it. `i` is that run, charwise from the
          # first non-blank character to the last; `a` is the same run plus
          # both border lines, as whole lines. On a function body that makes
          # cii "retype the body" and dai "delete the function".
          #
          # Upstream's own example puts this on `I`, but mini.ai ships no
          # builtin on `i`, and `i` is what the fingers expect.
          i.__raw = ''require("mini.extra").gen_ai_spec.indent()'';
        };
      };
    };

    plugins.mini-surround = {
      enable = true;

      # Default `n_lines` here is 20, which is tighter still, and `sd(` failing
      # silently on a call that wraps a long argument list reads as a bug.
      # Matched to mini.ai so the two agree on what counts as "nearby".
      settings = {
        n_lines = 500;
      };
    };
  };
}
