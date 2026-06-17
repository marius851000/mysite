{ buildArticlePage, buildBlog, ... }:

let
  personalBlog = buildBlog "Blog de marius" ./blog;

  reviewBlog = buildBlog "Critiques de marius" ./review;
in {
  "" = (buildArticlePage {} ./pages/index "/" null);

  "style.css" = ./style.css;

  blog = personalBlog;

  review = reviewBlog;
}
