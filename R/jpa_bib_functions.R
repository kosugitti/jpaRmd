#' @title Name spliter function
#' @importFrom magrittr %>%
#' @importFrom stringr str_split
#' @importFrom dplyr mutate
#' @importFrom dplyr rowwise
#' @importFrom humaniformat format_reverse
#' @importFrom humaniformat first_name
#' @importFrom humaniformat middle_name
#' @importFrom humaniformat last_name
#' @importFrom stringr str_sub
#' @importFrom stringr str_to_upper
#' @importFrom stringr str_detect
#' @importFrom stringr str_replace
#' @param df elements of data.frame contains NAME
#' @export
name_spliter <- function(df) {
  df %>%
    str_split(pattern = " and ") %>%
    unlist() %>%
    data.frame(Names = .) %>%
    rowwise() %>%
    mutate(authors_name_split = format_reverse(Names)) %>%
    # Whether to exclude from this name-split function like the organization name
    mutate(exFLG = if_else(str_detect(Names, pattern = "\\{"), TRUE, FALSE)) %>%
    mutate(
      first_name = if_else(exFLG, "", first_name(authors_name_split)),
      middle_name = if_else(exFLG, "", middle_name(authors_name_split)),
      last_name = if_else(exFLG, str_replace_all(Names, pattern = "\\{|\\}", ""), last_name(authors_name_split)),
      initial_first = if_else(exFLG, "", str_sub(first_name, start = 1, end = 1) %>% str_to_upper()),
      initial_middle = if_else(exFLG, "", str_sub(middle_name, start = 1, end = 1) %>% str_to_upper())
    ) %>%
    return()
}


#' @title pBibMaker function
#' @importFrom dplyr if_else
#' @param df Bib data frame
#' @export
pBibMaker <- function(df, underline) {
  tmp <- case_when(
    df$CATEGORY == "BOOK" ~ if_else(df$langFLG, print_English_book(df, underline),
      print_Japanese_book(df)
    ),
    df$CATEGORY == "ARTICLE" ~ if_else(df$langFLG, print_English_article(df, underline),
      print_Japanese_article(df, underline)
    ),
    df$CATEGORY == "INCOLLECTION" ~ if_else(df$langFLG, print_English_incollection(df, underline),
      print_Japanese_incollection(df)
    ),
    df$CATEGORY == "INPROCEEDINGS" ~ if_else(df$langFLG, print_English_inproceedings(df),
      print_Japanese_inproceedings(df)
    )
  )
  return(tmp)
}

#' @title prefixMaker function
#' @importFrom stringi stri_escape_unicode
#' @importFrom stringr str_replace_all
#' @param df Bib data frame
#' @export
prefixMaker <- function(df) {
  tmp.bibtexKey <- stri_escape_unicode(df$BIBTEXKEY) %>%
    str_replace_all(pattern = "\\\\u", replacement = "ux")
  prefix <- paste0("\\hypertarget{refs}{}
    \\leavevmode\\hypertarget{ref-", tmp.bibtexKey, "}{}%")
  return(prefix)
}


#' @title citationMaker function
#' @param df Bib data frame
#' @export
citationMaker <- function(df, ampersand = T) {
  if (df$langFLG) {
    tmp <- inLineCite_ENG(df, ampersand)
  } else {
    tmp <- inLineCite_JPN(df)
  }
  return(tmp)
}

#' @title Print name function(English)
#' @importFrom magrittr %>%
#' @importFrom dplyr mutate
#' @importFrom dplyr rowwise
#' @importFrom dplyr if_else
#' @importFrom stringr str_flatten
#' @param st Strings of name
#' @param switchFLG switch the order of first name and last name
#' @param ampersand it TRUE, combine last author with ampersand else "and"
#' @export
print_EName <- function(st, ampersand = T, switchFLG = FALSE) {
  st <- as.data.frame(st)
  st %>%
    rowwise() %>%
    mutate(
      initial_first = if_else(exFLG, "", paste0(initial_first, ".")),
      initial_middle = if_else(exFLG, "", paste0(initial_middle, ".")),
      initial_name = paste0(initial_first, if_else(initial_middle == "NA.", "", initial_middle)),
      pName = if_else(switchFLG,
        paste(initial_name, last_name),
        paste0(last_name, ", ", initial_name)
      )
    ) -> tmp

  # If authors have same name, don't abbreviate first name.
  pName.tmp <- tmp$pName %>% unlist()
  duplicated.name <- which(table(pName.tmp) > 1) %>% names()
  for (i in 1:NROW(tmp)) {
    if (str_detect(tmp$pName[i], pattern = duplicated.name) %>% sum()) {
      tmp$pName[i] <- paste0(tmp$last_name[i], ",", tmp$first_name[i])
    }
  }
  nameList <- tmp$pName %>% unlist()
  if (length(nameList) == 1) {
    ## single author
    pName <- nameList
  } else {
    ## co-authors(over 8)
    if (NROW(tmp) > 7) {
      ## if number of co-authors is over 8, write down first to 6th author's name and
      ## add "..." and last author's name.
      pName <- paste0(
        nameList[1:6] %>% str_flatten(collapse = ", "),
        "...",
        nameList[length(nameList)]
      )
    } else {
      # wirte down all author's name and add "," befor last author's name.
      # use & not and
      pName <- stringr::str_flatten(nameList[1:(length(nameList) - 1)], collapse = ", ")
      pName <- if (ampersand) {
        paste(pName, "\\&", nameList[length(nameList)])
      } else {
        paste(pName, "and", nameList[length(nameList)])
      }
    }
  }
  return(unlist(pName))
}

#' @title Print name function(Jpanese)
#' @param st Strings of Japanese name
#' @export
print_JName <- function(st) {
  st <- as.data.frame(st)
  centralDot <- stri_unescape_unicode("\\u30fb")
  triDots <- stri_unescape_unicode("\\u2026")
  pName <- paste0(st[1, ]$last_name, "\\ ", st[1, ]$first_name)
  if (NROW(st) > 1) {
    if (NROW(st) < 8) {
      # ii) if number of co-author is under 7, write down all author's name and add central dot
      for (i in 2:NROW(st)) {
        pName <- paste0(pName, centralDot, paste0(st[i, ]$last_name, "\\ ", st[i, ]$first_name))
      }
    } else {
      # iii) if number of co-author is over 8，write down first to 6th author's name and
      ## add "..." and last author's name.
      for (i in 2:6) {
        pName <- paste0(pName, centralDot, paste0(st[i, ]$last_name, "\\ ", st[i, ]$first_name))
      }
      pName <- paste0(
        pName, triDots,
        paste0(st[NROW(st), ]$last_name, "\\ ", st[NROW(st), ]$first_name)
      )
    }
  }
  # iv ) The books and articles in the name of a group, such as government, government offices,
  # research institutions, academic associations, and general private organizations,
  # the official name should be written without abbreviating it,
  # and they should be arranged in the same alphabetical order as for the names of individual authors.
  # v ) If there are no authors, list them in alphabetical order according to their titles.
  return(pName)
}

#' @title Print bib info function(English book)
#' @param df Strings of Bib info
#' @export
print_English_book <- function(df, underline = F) {
  name.tmp <- df$ListName
  if (underline) {
    eff <- "\\uline{"
  } else {
    eff <- "\\emph{"
  }
  title.tmp <- paste0(eff, df$TITLE, "}.")
  # i ) General examples (author), (year of publication), (book title), (place of publication: publisher)
  # ii) New editions: Always indicate the number of editions except for the first edition.
  # Editions should be abbreviated to ed.
  if (!is.na(df$EDITION)) {
    title.tmp <- paste0(title.tmp, "(", df$EDITION, "ed.)")
  }
  # iii)In the case of multiple editors, it should be abbreviated to Eds.
  if (!is.na(df$EDITOR)) {
    if (NROW(df$AUTHORs) == 1) {
      name.postfix <- "(Ed.)"
    } else {
      name.postfix <- "(Eds.)"
    }
    name.tmp <- paste0(name.tmp, name.postfix)
  }
  # v) Books in several volumes (author), (year of publication), (book title), (Vols),
  # (place of publication: publisher)
  if (!is.na(df$VOLUME)) {
    title.tmp <- paste0(title.tmp, "(Vols.", df$VOLUME, ")")
  }
  # vii) Transrations
  trans.tmp <- ""
  trans.info <- ""
  if (!is.na(df$TRANSAUTHOR)) {
    trans.tmp <- paste0("(", print_EName(df$TRANSAUTHORs, switchFLG = TRUE), ", ", df$TRANSWORK, ").")
    trans.info <- paste0(" (", df$TRANSINFO, ")")
  }
  pBib <- paste0(name.tmp, df$ListYear, title.tmp, " ", trans.tmp, df$ADDRESS, ":", df$PUBLISHER, trans.info)
  pBib <- paste0(pBib, ".")
  return(pBib)
}

#' @title Print bib info function(Japanese book)
#' @importFrom stringi stri_unescape_unicode
#' @param df Strings of Bib info
#' @export
print_Japanese_book <- function(df) {
  name.tmp <- df$ListName
  title.tmp <- df$TITLE
  # iii)Editorial and Supervisory Book
  if (!is.na(df$EDITOR)) {
    postfix <- stri_unescape_unicode("(\\u7de8)")
    name.tmp <- paste0(name.tmp, postfix)
  }
  # v)Books in several volumes (including thematic series, collections, etc.)
  if (!is.na(df$VOLUME)) {
    prefix <- stri_unescape_unicode("(\\u5168")
    postfix <- stri_unescape_unicode("\\u5dfb)")
    title.tmp <- paste0(title.tmp, prefix, df$VOLUME, postfix)
  }
  # ii) New edition, iii) reprints, and vi)  the book in several volumes
  # are handled by the Bib files (e.g., put it in the title; see Google Scholar)
  # vii)Transrated
  if (!is.na(df$JTITLE)) {
    E.part <- print_English_book(df)
    ## Editors
    if (!is.na(df$JKANYAKU)) {
      Jname <- print_JName(df$JKANYAKUs)
      postfix <- stri_unescape_unicode("(\\u76e3\\u8a33)")
      Jname <- paste0(Jname, postfix)
    } else {
      Jname <- print_JName(df$JAUTHORs)
      postfix <- stri_unescape_unicode("(\\u8a33)")
      Jname <- paste0(Jname, postfix)
    }
    J.part <- paste(df$GENCHOKANA, Jname, "(", df$JYEAR, ").", df$JTITLE, "\\ ", df$JPUBLISHER)
    pBib <- paste0(E.part, "(", J.part, ")")
  } else {
    pBib <- paste(name.tmp, df$ListYear, df$TITLE, "\\ ", df$PUBLISHER)
  }

  return(pBib)
}

#' @title Print bib info function(English article)
#' @param df Strings of Bib info
#' @export
print_English_article <- function(df, underline = F) {
  # (author's name), (year of publication), (title), (journal title), (number of copies), (page citations)
  TITLE.tmp <- title.tmp <- paste0(df$TITLE, ",")
  if (underline) {
    eff <- "\\uline{"
  } else {
    eff <- "\\emph{"
  }
  JOURNAL.tmp <- paste0(eff, df$JOURNAL, "},")
  Vol_and_Num.tmp <- ""
  df$VOLUME <- if_else(is.na(df$VOLUME), "", df$VOLUME)
  df$NUMBER <- if_else(is.na(df$NUMBER), "", df$NUMBER)
  if (df$VOLUME != "") {
    Vol_and_Num.tmp <- paste0(eff, df$VOLUME, "}")
  }
  if (df$NUMBER != "") {
    Vol_and_Num.tmp <- paste0(Vol_and_Num.tmp, "(", df$NUMBER, ")")
  }
  Vol_and_Num.tmp <- paste0(Vol_and_Num.tmp, ",")
  PAGES.tmp <- if (!is.na(df$PAGES)) {
    if (df$PAGES != "") {
      paste0(df$PAGES, ".")
    }
  }
  pBib <- paste(df$ListName, df$ListYear, TITLE.tmp, JOURNAL.tmp, Vol_and_Num.tmp, PAGES.tmp)
  ## DOI
  if (!is.na(df$DOI)) {
    pBib <- paste0(pBib, df$DOI)
  }
  return(pBib)
}

#' @title Print bib info function(Jaopanese article)
#' @param df Strings of Bib info
#' @export
print_Japanese_article <- function(df, underline = F) {
  # (Author's name), (Year of publication), (Title), (Title), (Number of copies), (Citation page)
  JOURNAL.tmp <- paste0(df$JOURNAL, ",")
  if (underline) {
    eff <- "\\uline{"
  } else {
    eff <- "\\emph{"
  }
  Vol_and_Num.tmp <- ""
  df$VOLUME <- if_else(is.na(df$VOLUME), "", df$VOLUME)
  df$NUMBER <- if_else(is.na(df$NUMBER), "", df$NUMBER)
  if (df$VOLUME != "") {
    Vol_and_Num.tmp <- paste0(eff, df$VOLUME, "}")
  }
  if (df$NUMBER != "") {
    Vol_and_Num.tmp <- paste0(Vol_and_Num.tmp, "(", df$NUMBER, ")")
  }
  Vol_and_Num.tmp <- paste0(Vol_and_Num.tmp, ",")
  PAGES.tmp <- if (!is.na(df$PAGES)) {
    if (df$PAGES != "") {
      paste0(df$PAGES, ".")
    }
  }
  pBib <- paste(df$ListName, df$ListYear, df$TITLE, "\\ ", JOURNAL.tmp, Vol_and_Num.tmp, PAGES.tmp)
  ## DOI
  if (!is.na(df$DOI)) {
    pBib <- paste0(pBib, "\\ \\verb|", df$DOI, "|")
  }
  return(pBib)
}

#' @title Print bib info function(in English collection)
#' @importFrom dplyr if_else
#' @param df Strings of Bib info
#' @export
print_English_incollection <- function(df, underline = F) {
  if (underline) {
    eff <- "\\uline{"
  } else {
    eff <- "\\emph{"
  }
  prefix <- "In "
  postfix <- if_else(NROW(df$EDITOR) > 1, "(Eds.),", "(Ed.),")
  inbook.tmp1 <- paste0(prefix, print_EName(df$EDITORs, switchFLG = TRUE), postfix)
  edition.tmp <- if_else(!is.na(df$EDITION), paste0(df$EDITION, " ed., "), "")
  inbook.tmp2 <- paste0(eff, df$BOOKTITLE, "} (", edition.tmp, " pp.", df$PAGES, ").")

  pBib <- paste(df$ListName, df$ListYear, df$TITLE, inbook.tmp1, inbook.tmp2, df$ADDRESS, ":", df$PUBLISHER, ".")
  return(pBib)
}

#' @title Print bib info function(in Japanese collection)
#' @importFrom stringi stri_unescape_unicode
#' @param df Strings of Bib info
#' @export
print_Japanese_incollection <- function(df) {
  postfix <- stri_unescape_unicode("(\\u7de8)")
  inbook.tmp1 <- paste0("\\ ", print_JName(df$EDITORs), postfix)
  edition.tmp <- if_else(!is.na(df$EDITION), paste0(df$EDITION, " ed.,"), "")
  inbook.tmp2 <- paste0(df$BOOKTITLE, " (", edition.tmp, "pp.", df$PAGES, ").")
  pBib <- paste(df$ListName, df$ListYear, df$TITLE, inbook.tmp1, inbook.tmp2, df$PUBLISHER)
  return(pBib)
}

#' @title Print bib info function(in English Proceedings)
#' @param df Strings of Bib info
#' @export
print_English_inproceedings <- function(df) {
  pBib <- paste(df$ListName, df$ListYear, df$TITLE, df$JOURNAL, ".\ ", df$PAGES, ".")
  return(pBib)
}

#' @title Print bib info function(in Japanese Proceedings)
#' @param df Strings of Bib info
#' @export
print_Japanese_inproceedings <- function(df) {
  pBib <- paste(df$ListName, df$ListYear, df$TITLE, df$JOURNAL, ".\\ ", df$PAGES, ".")
  return(pBib)
}

#' @title in-Line Cittion(in English)
#' @importFrom dplyr select
#' @param df Bib.df File from jpa_cite
#' @export
inLineCite_ENG <- function(df, ampersand) {
  # depends on the number of authors
  tmp_name <- as.data.frame(df$AUTHORs)
  # ampersand
  if (ampersand) {
    tmp_connecter <- " \\& "
  } else {
    tmp_connecter <- "\\ and\\ "
  }
  ### duplicated cheker
  dplCheck <- df$dplFLG

  ## First time
  NR <- NROW(tmp_name)
  if (NR > 1) {
    ### multi-Authors
    citeName1 <- ""
    for (i in 1:(NR - 1)) {
      if (dplCheck > 1) {
        tmp1 <- paste0(tmp_name[i, ]$initial_first, ".", tmp_name[i, ]$last_name, ", ")
      } else {
        tmp1 <- paste0(tmp_name[i, ]$last_name, ", ")
      }
      citeName1 <- paste0(citeName1, tmp1)
    }
    ### Last Author
    tmp1 <- paste0(tmp_connecter, tmp_name[NR, ]$last_name)
    if (dplCheck > 1) {
      tmp1 <- paste0(tmp_connecter, tmp_name[NR, ]$initial_first, ".", tmp_name[NR, ]$last_name)
    }
    ### combine All Authors
    citeName1 <- paste0(citeName1, tmp1)
  } else {
    ### Single Author
    citeName1 <- tmp_name[1, ]$last_name
    if (dplCheck > 1) {
      citeName1 <- paste0(tmp_name[1, ]$initial_first, ".", tmp_name[1, ]$last_name)
    }
  }

  ## Second time and after
  ### Single AUthor
  citeName2 <- tmp_name[1, ]$last_name
  if (dplCheck > 1) {
    citeName2 <- paste0(tmp_name[1, ]$initial_first, ".", tmp_name[1, ]$last_name)
  }
  ### Two AUthors
  if (NROW(tmp_name) == 2) {
    citeName2 <- paste0(citeName2, tmp_connecter, tmp_name[2, ]$last_name)
    if (dplCheck > 1) {
      citeName2 <- paste0(citeName2, tmp_connecter, tmp_name[2, ]$initial_first, ".", tmp_name[2, ]$last_name)
    }
  }
  ### More than 2 Authors
  if (NROW(tmp_name) > 2) {
    citeName2 <- paste0(citeName2, "\\ et al.")
  }


  citeCheckFLG <- paste0(citeName1, "-", df$YEAR)
  return(data.frame(citeName1, citeName2, citeCheckFLG))
}

#' @title in-Line Cittion(in Japanese)
#' @importFrom dplyr select
#' @param df Bib.df File from jpa_cite
#' @export
inLineCite_JPN <- function(df) {
  # depends on number of Authors
  tmp_name <- as.data.frame(df$AUTHORs)
  ### duplicated cheker
  dplCheck <- df$dplFLG
  NR <- NROW(tmp_name)
  ## First time
  if (NR > 1) {
    ### multi-Authors
    citeName1 <- ""
    for (i in 1:(NR - 1)) {
      if (dplCheck > 1) {
        tmp1 <- paste0(tmp_name[i, ]$last_name, tmp_name[i, ]$first_name, stri_unescape_unicode("\\u30fb"))
      } else {
        tmp1 <- paste0(tmp_name[i, ]$last_name, stri_unescape_unicode("\\u30fb"))
      }
      citeName1 <- paste0(citeName1, tmp1)
    }
    ### Last Author
    tmp1 <- paste0(tmp_name[NR, ]$last_name)
    if (dplCheck > 1) {
      tmp1 <- paste0(tmp_name[NR, ]$last_name, tmp_name[NR, ]$first_name)
    }
    citeName1 <- paste0(citeName1, tmp1)
  } else {
    ### single-Author
    citeName1 <- tmp_name[1, ]$last_name
    if (dplCheck > 1) {
      citeName1 <- paste0(tmp_name[1, ]$last_name, tmp_name[1, ]$first_name)
    }
  }
  ## Second time, and after
  citeName2 <- tmp_name[1, ]$last_name
  if (dplCheck > 1) {
    citeName2 <- paste0(tmp_name[1, ]$last_name, tmp_name[1, ]$first_name)
  }
  if (NROW(tmp_name) == 2) {
    citeName2 <- paste0(citeName2, stri_unescape_unicode("\\u30fb"), tmp_name[2, ]$last_name)
    if (dplCheck > 1) {
      citeName2 <- paste0(
        citeName2, stri_unescape_unicode("\\u30fb"),
        paste0(tmp_name[2, ]$last_name, tmp_name[2, ]$first_name)
      )
    }
  }
  if (NROW(tmp_name) > 2) {
    citeName2 <- paste0(citeName2, stri_unescape_unicode("\\u4ed6"))
  }
  citeCheckFLG <- paste0(citeName1, "-", df$YEAR)
  return(data.frame(citeName1, citeName2, citeCheckFLG))
}
