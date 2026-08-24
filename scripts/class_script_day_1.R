# In course Script
# Mara Weber
# 24.08.26


# Install and import packages
# install.package("pacman")
pacman::p_load("rvest", "tidyverse", "arrow", "quanteda", "httr2", "WikipediR", "XML", "quanteda.textplots", "quanteda.textstats")

# Define the URL of the page we want to scrape
url <- read_html("https://en.wikipedia.org/wiki/List_of_Nobel_laureates")

# Extract the table from the page
nobel_table <- url %>%
  html_node("table") %>%   # selects the first table on the page
  html_table()              # converts the HTML table to a data frame


get_last_revision <- function(page_title, continue_parameter = NULL,
                              user_agent = "Polmem_ucl") {
  baseurl <- "https://en.wikipedia.org/w/api.php"
  
  params <- list(
    action  = "query",
    format  = "json",
    titles  = as.character(page_title),
    prop    = "revisions",
    rvprop  = "ids|timestamp|user|userid|comment|size|content",
    rvslots = "main",
    rvlimit = 1,       # just the latest
    rvdir   = "older"  # newest first; single item is current revision
  )
  
  if (!is.null(continue_parameter)) params$rvcontinue <- continue_parameter
  
  resp <- request(baseurl) %>%
    req_user_agent(user_agent) %>%
    req_url_query(!!!params) %>%
    req_perform()
  
  json <- resp_body_json(resp)
  
  pages <- json$query$pages
  if (is.null(pages) || !length(pages)) return(data.frame())
  
  pg <- pages[[1]]
  if (is.null(pg$revisions) || !length(pg$revisions)) return(data.frame())
  
  rv <- pg$revisions[[1]]
  slots <- rv$slots$main
  
  data.frame(
    page_title    = pg$title %||% NA_character_,
    page_id       = as.character(pg$pageid %||% NA),
    revid         = as.character(rv$revid %||% NA),
    parentid      = as.character(rv$parentid %||% NA),
    user          = as.character(rv$user %||% NA_character_),
    userid        = as.character(rv$userid %||% NA),
    timestamp     = as.character(rv$timestamp %||% NA_character_),
    size          = as.character(rv$size %||% NA),
    comment       = as.character(rv$comment %||% NA_character_),
    contentmodel  = slots$contentmodel %||% NA_character_,
    contentformat = slots$contentformat %||% NA_character_,
    content       = slots[["*"]] %||% NA_character_,
    check.names = FALSE,
    stringsAsFactors = FALSE
  )
}

# Applying the function
page_content_revision <- get_last_revision("List of Nobel laureates")

# WikipediR wrapper
page_content_nobel <- WikipediR::page_content(
  language = "en", project = "wikipedia",
  page_name = "List of Nobel laureates", clean_response = TRUE
)

# Parsing the html
parsed_html <- htmlParse(page_content_nobel, asText = TRUE)
first_table <- readHTMLTable(parsed_html, which = 1, stringsAsFactors = FALSE)
colnames(first_table) <- first_table[1, ]
first_table <- first_table[-1, ]

# Retrieving all pages in the category (but not content yet)
all_pages_category_women <- WikipediR::pages_in_category(
  "en", "wikipedia", categories = "Women Nobel laureates",
  clean_response = TRUE
)
all_pages_category_women <- all_pages_category_women[-c(1, 2), ]

nobel_table <- nobel_table %>%
  slice(-n()) %>%
  pivot_longer(-Year, names_to = "category", values_to = "laureates") %>%
  rename(title = laureates)

women <- left_join(all_pages_category_women, nobel_table, by = "title") %>%
  select(title, category, Year) %>%
  mutate(gender = "female")

men <- nobel_table %>%
  filter(!title %in% women$title) %>%
  mutate(gender = "male")

all_winners <- bind_rows(women, men)


clean_text_data <- read_parquet("/Users/maraweber/Documents/PGTA/summerschool/data/wikipedia_nobel_biographies_summaries_clean.parquet")
glimpse(clean_text_data)

clean_text_data <- clean_text_data %>%
  drop_na(title)

# Gender distribution
proptable <- prop.table(table(clean_text_data$gender))
round(proptable, digits = 2)

# Create corpus
corpus <- corpus(clean_text_data, text_field = "extract", docnames = "pageid")

# Tokenization
tokens <- corpus %>%
  tokens(remove_punct = TRUE,
         remove_symbols = TRUE) %>%
  tokens_remove(stopwords("en"), padding = FALSE) %>%
  tokens_tolower() %>%
  tokens_compound(pattern = clean_text_data$title, concatenator = "_", case_insensitive = FALSE) %>%
  tokens_compound(pattern = "nobel prize", concatenator = "_", case_insensitive = FALSE) %>%
  tokens_wordstem()

# Create a document-feature matrix (DFM)
dfm <- dfm(tokens) %>%
  dfm_trim(min_termfreq = 0.8, termfreq_type = "quantile")

# tf-idf weighting
dfm_tfidf_mat <- dfm_tfidf(dfm)

clean_text_female <- clean_text_data %>% filter(gender == "female")
clean_text_male   <- clean_text_data %>% filter(gender == "male")

corpus_female <- corpus(clean_text_female, text_field = "extract", docnames = "pageid")
corpus_male   <- corpus(clean_text_male, text_field = "extract", docnames = "pageid")

tokens_female <- corpus_female %>%
  tokens(remove_punct = TRUE, remove_symbols = TRUE) %>%
  tokens_remove(stopwords("en"), padding = FALSE) %>%
  tokens_tolower() %>%
  tokens_wordstem()

tokens_male <- corpus_male %>%
  tokens(remove_punct = TRUE, remove_symbols = TRUE) %>%
  tokens_remove(stopwords("en"), padding = FALSE) %>%
  tokens_tolower() %>%
  tokens_wordstem()

dfm_female <- dfm(tokens_female)
dfm_male   <- dfm(tokens_male)

dfm_female %>%
  textstat_frequency(n = 15) %>%
  ggplot(aes(x = reorder(feature, frequency), y = frequency)) +
  geom_point() +
  coord_flip() +
  labs(x = NULL, y = "Frequency") +
  theme_minimal()

dfm_male %>%
  textstat_frequency(n = 15) %>%
  ggplot(aes(x = reorder(feature, frequency), y = frequency)) +
  geom_point() +
  coord_flip() +
  labs(x = NULL, y = "Frequency") +
  theme_minimal()

set.seed(132)
textplot_wordcloud(dfm_female, max_words = 100)

set.seed(132)
textplot_wordcloud(dfm_male, max_words = 100)


