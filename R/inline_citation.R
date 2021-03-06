#' @title inLine Citation
#' @importFrom dplyr mutate
#' @importFrom dplyr select
#' @importFrom dplyr if_else
#' @importFrom magrittr %>%
#' @importFrom stringr str_extract
#' @importFrom stringr str_extract_all
#' @importFrom stringr str_locate
#' @importFrom stringr str_detect
#' @importFrom stringr str_replace
#' @importFrom stringr str_sub
#' @importFrom dplyr left_join
#' @param st A line of text
#' @param bib.df Bib.df object created by bib_to_DF function
#' @return replace statement
#' @examples
#' # bib_to_DF(Rmd_file = "RmdFileName",Bib_file = "BibFileName")
#' @export
#'
#'
inLineCitation <- function(st, bib.df) {
  item <- st %>% str_extract(pattern = "@[\\[a-zA-Z0-9-_\\.\\p{Hiragana}\\p{Katakana}\\p{Han}]*")
  loc <- st %>% str_locate(item)
  loc <- loc[1] - 1
  tp <- FALSE
  if (loc > 0) {
    tp <- str_sub(st, loc, loc) %>% str_detect(pattern = "\\[")
  }

  tmp.df <- data.frame()
  if (tp) {
    ### citation on the end of line
    ##### retake citation key
    item <- st %>% str_extract(pattern = "\\[.*?\\]")
    ##### citaton data frame
    tmp.df <- item %>%
      str_extract_all(pattern = "@[a-zA-Z0-9-_\\.\\p{Hiragana}\\p{Katakana}\\p{Han}]*", simplify = T) %>%
      t() %>%
      as.data.frame() %>%
      mutate(KEY = str_replace(V1, pattern = "@", replacement = "")) %>%
      ### join with bib.df
      left_join(bib.df, by = c("KEY" = "BIBTEXKEY")) %>%
      ### get the citation name
      select(V1, KEY, citeName1, citeName2, ListYear, count) %>%
      mutate(ListYear = str_extract(ListYear, "[a-z0-9]{4,5}")) %>%
      mutate(citeName = if_else(count > 0, citeName2, citeName1)) %>%
      mutate(citation = paste0(citeName, ",\\ ", ListYear))

    word <- tmp.df$citation %>% paste0(collapse = "; ")
    word <- paste0("(", word, ")")
    ### reform for regular expression
    item <- str_replace(item, pattern = "\\[", replacement = "\\\\[") %>%
      str_replace(pattern = "\\]", replacement = "\\\\]")
  } else {

    ### citation in the line
    KEY <- str_replace(item, pattern = "@", replacement = "")
    ref.df <- bib.df[bib.df$BIBTEXKEY == KEY, ] %>%
      mutate(ListYear = str_sub(ListYear, 1, str_length(ListYear) - 1))
    if (bib.df[bib.df$BIBTEXKEY == KEY, ]$count == 0) {
      word <- paste0(ref.df$citeName1, ref.df$ListYear)
    } else {
      # more
      word <- paste0(ref.df$citeName2, ref.df$ListYear)
    }
  }


  return(list(item = item, word = word, key = tmp.df$KEY))
}
