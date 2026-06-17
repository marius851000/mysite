{ pkgs, util, ... }:

with pkgs.lib.strings;

rec {
  # with the title, the body and the path of the page, return a derivation containing the page
  # path is the path relative to the site root, folder is the folder containing the page, used for substitution. May be null.
  buildPage = extra_meta: body: path: folder: let
    wrapped_main = wrapMain extra_meta body path;
  in wrapped_main;

  wrapMain = extra_meta: body: path: let
    title = if extra_meta ? title then extra_meta.title else throw "article without title: ${path}";

    modified_date = if extra_meta ? "modified-date" then extra_meta."modified-date" else if extra_meta ? "date" then extra_meta."date" else null;

    extra_header = "<meta property=\"og:title\" content=\"${title}\" />" +
      (if extra_meta ? type then "\n<meta property=\"og:type\" content=\"${extra_meta.type}\" />" else "") +
      (if extra_meta ? date then "\n<meta property=\"article:published_time\" content=\"${util.dateToDefaultISO8601 extra_meta.date}\" />" else "") +
      (if modified_date != null then "\n<meta property=\"article:modified_time\" content=\"${util.dateToDefaultISO8601 modified_date}\" />" else "") +
      (if extra_meta ? lang then "\n<meta property=\"og:locale\" content=\"${extra_meta.lang}_FR\" />" else "") +
      (if extra_meta ? description then "\n<meta property=\"og:description\" content=\"${extra_meta.description}\" />" else "");

    lang = if extra_meta ? lang then extra_meta.lang else "fr";
  in pkgs.stdenvNoCC.mkDerivation {
    name = "header-html-wrapped";

    phases = "installPhase";

    nativeBuildInputs = [ pkgs.prettier ];

    installPhase = ''
      cp ${../header.html} result.html
      substituteInPlace result.html \
        --replace-quiet {{extra_header}} ${escapeShellArg extra_header} \
        --replace-quiet {{lang}} ${escapeShellArg lang} \
        --replace-quiet {{title}} ${escapeShellArg title}

      cat ${body} >> result.html

      cat ${../footer.html} >> result.html

      substituteInPlace result.html \
        --replace-quiet "<img src=\"./" "<img src=\"${path}/"

      prettier --parser html result.html > $out
    '';

    postname = ".html";
  };


  patchBody = body: path: folder: let
    placeholder_file_path = folder + "/placeholder.nix";
    placeholder_exist = builtins.pathExists placeholder_file_path;
    placeholder_value = if (folder != null && placeholder_exist) then (
      import placeholder_file_path { inherit pkgs; }
    ) else [];
    placeholder_replace_command = builtins.concatStringsSep "\n" (builtins.map
      (x:
        ''substituteInPlace $out --replace-fail ${escapeShellArg ("{{" + x.holder + "}}")} ${escapeShellArg x.to}''
      )
      placeholder_value);
  in pkgs.stdenvNoCC.mkDerivation {
      name = "patched-body";

      phases = "installPhase";

      installPhase = ''
        cp ${body} $out
        ${placeholder_replace_command}
      '';
    };

  buildGenericPage = bodyWrapper: metadata: folder: path: key: let
    data_base = {
      type = "webPage";
    }
      // metadata
      // (builtins.fromTOML (builtins.readFile (builtins.toPath (folder + "/meta.toml"))));

    lang = data_base.lang or null;

    data = if data_base.type == "userReview" && !(data_base ? "title") then (
      data_base // (if lang == "fr" then {
        titleFormatted = "Critique de <cite>${data_base.reviewedName}</cite>";
        title = "Critique de ${data_base.reviewedName}";
      } else if lang == "en" then {
        titleFormatted = "Review of <cite>${data_base.reviewedName}</cite>";
        title = "Review of ${data_base.reviewedName}";
      } else throw "Generate title of review: Unsupported language: ${lang}")
    )
    else data_base;

    body_patched = patchBody "${folder}/body.html" path folder;
    wrapped_in_article = bodyWrapper data body_patched path;
    wrapped_in_header = wrapMain data wrapped_in_article path;
  in pkgs.stdenv.mkDerivation {
    name = "site-blog-page";

    passthru = {
      inherit key data lang;
      schemaType = util.getSchemaType data;
      datePublished = data.date or "1970-01-01"; #TODO: do not actually put a date
    };

    phases = "installPhase";

    installPhase = ''
      mkdir -p $out
      ln -s ${folder}/* $out
      rm -f $out/body.html
      rm -f $out/meta.toml
      rm -f $out/index.html
      ln -s ${wrapped_in_header} $out/index.html
    '';

    postname = "";
  };
}
