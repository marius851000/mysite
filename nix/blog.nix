{ pkgs, util, generic_pagegen, ... }:

with pkgs.lib.strings;

rec {
  buildArticlePage = generic_pagegen.buildGenericPage wrapArticle;

  wrapArticle = extra_meta: body: path: let
    lang = extra_meta.lang;

    post_title_stuff = (util.createCreativeWorkShortMeta extra_meta) +
      (if extra_meta.type == "userReview" then (util.formatWorkFromData extra_meta "reviewed" lang "itemReviewed") else "");

    basic_content = if extra_meta.type == "blogPost" then {
      "itemtype" = "https://schema.org/BlogPosting";
      "bodyprop" = "articleBody";
    } else if (extra_meta.type == "webPage" || extra_meta.type == "aboutPage") then {
      "itemtype" = if extra_meta.type == "aboutPage" then "https://schema.org/AboutPage" else "https://schema.org/WebPage";
      "bodyprop" = "mainContentOfPage";
    } else if extra_meta.type == "userReview" then {
      "itemtype" = "https://schema.org/UserReview";
      "bodyprop" = "reviewBody";
    } else throw "unknown type: ${extra_meta.type}";
  in pkgs.stdenvNoCC.mkDerivation {
    name = "wrapped-article";

    phases = "installPhase";

    installPhase = ''
      cp ${../article_header.html} ./header.html
      cp ${../article_footer.html} ./footer.html

      for file in header.html footer.html; do
        substituteInPlace $file \
          --replace-quiet {{page_url}} ${escapeShellArg (util.urlFromPath path)} \
          --replace-quiet {{title}} ${escapeShellArg extra_meta.titleFormatted or extra_meta.title} \
          --replace-quiet {{post_title_stuff}} ${escapeShellArg post_title_stuff} \
          --replace-quiet {{itemtype}} ${escapeShellArg basic_content.itemtype} \
          --replace-quiet {{bodyprop}} ${escapeShellArg basic_content.bodyprop}
      done

      cp ./header.html $out
      cat ${body} >> $out
      cat ./footer.html >> $out
    '';
  };

  buildBlogIndex = blogTitle: blogPosts: path:
    let
      sortedBlogPosts = pkgs.lib.reverseList (pkgs.lib.sortOn (b: b.date) (pkgs.lib.mapAttrsToList (key: content: content) blogPosts));

      instructionsList = pkgs.lib.map
      (content: ''
        echo "<li>
          <span itemscope itemprop=\"blogPost\" itemtype=\"https://schema.org/BlogPosting\" itemid=\"${util.urlFromPath (path + "/" + content.key)}\">
            <a href=\"${path}/${content.key}\" itemprop=\"url\">${content.date} ${content.lang}: <span itemprop=\"headline\">${content.data.titleFormatted or content.data.title}</span></a>
          </span>
        </li>" >> $out
      '') sortedBlogPosts;

      instructions = pkgs.lib.concatStringsSep "\n" instructionsList;

      body = pkgs.stdenvNoCC.mkDerivation {
        name = "site-blog-index-body";

        phases = "installPhase";

        installPhase = ''
          echo "<div itemscope itemtype=\"https://schema.org/Blog\" itemid=\"${util.urlFromPath path}\">" >> $out
          echo "<h1 itemprop=\"name\">${blogTitle}</h1>" >> $out

          echo "<ul>" >> $out
          ${instructions}
          echo "</ul>" >> $out
          echo "</div>" >> $out
        '';
      };
    in
      generic_pagegen.buildPage {
        title = blogTitle;
      } body path null;

  buildBlog = title: folder: path: let
    subfolder = builtins.readDir folder;

    data = pkgs.lib.mapAttrs (key: type: buildArticlePage
      { type = "blogPost"; }
      (builtins.path {
        path = folder + ("/" + key);
        # avoid problem with name containing invalid characters
        name = "blog-entry-source";
      })
      (path + ("/" +  key))
      key
    ) subfolder;

    instructionsList = pkgs.lib.mapAttrsToList
      (key: content: "ln -s ${content.page} $out/${key}") data;

    instructions = pkgs.lib.concatStringsSep "\n" instructionsList;
  in
    pkgs.stdenv.mkDerivation {
      name = "site-blog";

      phases = "installPhase";

      installPhase = ''
        mkdir $out

        ${instructions}

        ln -s ${buildBlogIndex title data path} $out/index.html
      '';

      postname = "";
    };
}
