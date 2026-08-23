# Day 2: Supervised Learning, Word Embeddings & LLMs
#
# Extracted verbatim from notes/day2.qmd for review/running outside
# Quarto. Run top to bottom from the scripts/ folder (paths are
# relative to this file's location, same as in the .qmd).
#
# Requires: tidyverse, arrow, quanteda, quanteda.textmodels, caret,
# data.table, text2vec, ggplot2, ggrepel, rollama
#
# Two chunks need manual input before they'll run:
#   - "Load embeddings": set `path` to a real GloVe/Dolma embeddings file
#   - "Ollama": needs a local Ollama server running (ping_ollama())

# ---- Supervised Learning: train/test split ---------------------------

library(tidyverse)
library(arrow)
library(quanteda)
library(quanteda.textmodels)

# Import data
clean_text_data <- read_parquet("../data/wikipedia_nobel_biographies_summaries_clean_extended.parquet")

# Drop missings
clean_text_data <- clean_text_data %>%
  filter(pageid != 7152417)

# Create training and test set
set.seed(123)

clean_text_data$train <- sample(x = c(TRUE, FALSE),
                            size = nrow(clean_text_data),
                            replace = TRUE,
                            prob = c(.8, .2))

# we first create a corpus
corpus <- corpus(clean_text_data, text_field = "extract", docnames = "pageid")

# Convert to a DFM
dfm <- corpus %>%
  tokens() %>%
  dfm() %>%
  dfm_remove(stopwords("en"))

# Subset to training set observations
dfm_train <- dfm_subset(dfm, train)

# Subset to test set observations
dfm_test <- dfm_subset(dfm, !train)

# Check dimensions
dim(dfm_train) # 808 documents and 8239 tokens
dim(dfm_test) # 200 documents and 8239


# ---- Dictionaries: Agency & Communion ---------------------------------
# Pietraszkiewicz, Formanowicz, Gustafsson Sendén, Boyd, Sikström &
# Sczesny (2019), "The Big Two Dictionaries: Capturing Agency and
# Communion in Natural Language" (European Journal of Social Psychology)
# https://doi.org/10.1002/ejsp.2561 — dictionaries from https://osf.io/p7fzb/

corp <- corpus(clean_text_data, text_field = "extract", docnames = "pageid")

toks <- tokens(corp, remove_punct = TRUE) %>%
  tokens_tolower()

dfm_all <- dfm(toks)

# Agency & Communion dictionary (Pietraszkiewicz et al. 2019, https://osf.io/p7fzb/)
agency_words <- readLines("../data/agency_dictionary.txt")
communion_words <- readLines("../data/communion_dictionary.txt")

dict_agency_communion <- dictionary(list(
  agency    = agency_words,
  communion = communion_words
))

dfm_ac <- dfm_lookup(dfm_all, dict_agency_communion)

# normalize by document length so longer bios don't just score higher
dfm_ac_prop <- dfm_weight(dfm_ac, scheme = "prop")

ac_by_doc <- convert(dfm_ac_prop, to = "data.frame") %>%
  bind_cols(gender = docvars(dfm_all, "gender"))

# compare agentic vs. communal language by gender
ac_by_doc %>%
  group_by(gender) %>%
  summarise(mean_agency = mean(agency), mean_communion = mean(communion))


# ---- Naive Bayes Classification ---------------------------------------

y <- factor(docvars(dfm_train, "gender"))
nb_train <- textmodel_nb(x = dfm_train, y = y, prior = "docfreq")

class_test <- predict(nb_train, newdata = dfm_test, type = "class")
docvars(dfm_test, "pred_nb")  <- class_test

confusion_test <- table(
  predicted = docvars(dfm_test, "pred_nb"),
  truth     = docvars(dfm_test, "gender")
)
confusion_test


# ---- Model evaluation ---------------------------------------------------

library(caret)
confusion_test_statistics <- confusionMatrix(confusion_test,
                                              positive = "female")

confusion_test_statistics

# Task: Can we build a predictor for STEM vs. non-STEM prices?

clean_text_data$stem <- ifelse(clean_text_data$category %in% c("Chemistry", "Physiologyor Medicine", "Medicine", "Physics"), "STEM", "non-STEM")


corp <- corpus(clean_text_data, text_field = "extract", docnames = "pageid")

toks <- tokens(corp, remove_punct = TRUE) %>%
  tokens_tolower()

dfm_all <- dfm(toks)

dfm_train <- dfm_subset(dfm_all, train)
dfm_test  <- dfm_subset(dfm_all, !train)

y <- factor(docvars(dfm_train, "stem"))
nb_train <- textmodel_nb(x = dfm_train, y = y, prior = "docfreq")

class_test <- predict(nb_train, newdata = dfm_test, type = "class")
docvars(dfm_test, "pred_nb")  <- class_test

confusion_test <- table(
  predicted = docvars(dfm_test, "pred_nb"),
  truth     = docvars(dfm_test, "stem")
)
confusion_test

confusion_test_statistics <- confusionMatrix(confusion_test,
                                              positive = "STEM")

confusion_test_statistics


# ---- Word Embeddings ----------------------------------------------------

df <- arrow::read_parquet("../data/wikipedia_nobel_biographies_summaries_clean.parquet")

df <- df %>%
  drop_na()

library(data.table)

# path to your embeddings file
path <- "path/to/your/glove_or_dolma_embeddings.txt"

# Read Glove file (no header line, unlike fastText)
emb <- fread(path,header = FALSE,quote = "",encoding = "UTF-8")

# Split into words + vectors
words   <- emb[[1]]
glove <- as.matrix(emb[, -1, with = FALSE])
rownames(glove) <- words

# Example: look up vector for "dog"
glove["dog", ]

# dimensions
dim(glove)

# The Glove embeddings contain 1200001 terms and 300 dimensions (columns).

library(text2vec)

similarities <- function(target_word, n){

  # Extract embedding of target word
  target_vector <- glove[which(rownames(glove) %in% target_word),]

  # Calculate cosine similarity between target word and other words
  target_sim <- sim2(glove, matrix(target_vector, nrow = 1))

  # Report nearest neighbours of target word
  names(sort(target_sim[,1], decreasing = T))[1:n]

}

similarities("woman", n = 7)
similarities("men", n = 7)

library(text2vec)
library(quanteda)

# Construct corpus
corp <- corpus(df, text_field = "extract")

# Create vocab list based on dfm
vocab <- featnames(
  dfm(tokens(corp, remove_punct = TRUE) %>%
      tokens_tolower() %>%
      tokens_remove(stopwords("en"))))

# Create function that selects the nearest neighbors
nearest_from_summaries <- function(glove, query, top_n = 20, vocab = NULL) {
  rn   <- rownames(glove)
  cand <- if (is.null(vocab)) glove else glove[rn %in% vocab, , drop = FALSE]

  # expand wildcards (case-insensitive) and collect matches
  to_rx <- function(q) paste0("^", gsub("\\*", ".*", tolower(q)), "$")
  matches <- unique(unlist(lapply(query, function(q)
    grep(to_rx(q), rn, ignore.case = TRUE, value = TRUE)
  )))

  q_vec <- colMeans(glove[matches, , drop = FALSE])

  sims <- text2vec::sim2(cand, matrix(q_vec, nrow = 1),
                         method = "cosine", norm = "l2")[, 1]

  sims <- sims[setdiff(names(sims), matches)]
  sort(sims, decreasing = TRUE)[1:top_n]
}

# 3) Examples
# "female concept" neighbours (woman, women, female*)
nn_female <- nearest_from_summaries(glove,
                                    query = c("woman*", "women", "female*"),
                                    top_n = 20, vocab = vocab)

# "male concept" neighbours (man, men, male*)
nn_male <- nearest_from_summaries(glove,
                                  query = c("man", "men", "male*"),
                                  top_n = 20, vocab = vocab)

nn_female[1:20]
nn_male[1:20]


# ---- Visualization --------------------------------------------------------

library(ggplot2)

show_map <- function(words){
  M <- glove[intersect(words, rownames(glove)), , drop=FALSE]
  Z <- prcomp(M, center=TRUE, scale.=FALSE)$x[,1:2]

  df <- data.frame(Z, word=rownames(Z))
  ggplot(df, aes(PC1, PC2, label=word)) +
    geom_point() + ggrepel::geom_text_repel(size=3)
}

show_map(c("einstein","curie","planck","nobel","physicist","chemist", "literature", "ernaux", "peace", "literatur", "peac", "united"))


# ---- What is Ollama? ------------------------------------------------------

library(rollama)

# available models you have installed locally
list_models()

# Example usage
# pull_model("mistral:7B") # download a model

ping_ollama() # let's check if it is there

# We can simply talk to the model
rollama::query("What is the capital of New York", model = "llama3.1")

# lets construct the query

# Therefore we need a system message and a user prompt template.
# A system message usually starts with a role we're assigning.

df$zero <- NA_character_

for (i in 1:2) {
  print(i)
  question <- "Task: You're a research assistant that helps to analyze texts. Your aim is to classify whether the summary of a biographie describes a female or a male nobel price winner."
  text <- df$extract[i]
  question <- paste(question, text)
  result <- query(question, model ="llama3.1")
  print(result)
  df$zero[i] <- result[[1]]$message$content
}
