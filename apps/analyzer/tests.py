# The Bayesian classifier test has been removed as it tests unused functionality.
# The PhraseFilter, Tokenizer, and reverend.Bayes classes are not used in production.
#
# NewsBlur's actual classifier functionality uses the MongoDB models:
# - MClassifierFeed
# - MClassifierAuthor
# - MClassifierTitle
# - MClassifierTag
#
# These models are actively used throughout the codebase for the training/classification
# features, but they don't use the Bayesian approach that was being tested here.
