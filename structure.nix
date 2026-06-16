{ buildArticlePage, buildBlog, ... }:

{
  "" = (buildArticlePage {} ./pages/index "/" null).page;

  "style.css" = ./style.css;

  blog = buildBlog "Blog de marius" ./blog;

  review = buildBlog "Critiques de marius" ./review;
}
