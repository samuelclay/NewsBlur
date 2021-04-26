library(RPostgreSQL)
drv = dbDriver("PostgreSQL")
db <- dbConnect(drv, dbname="newsblur", user="newsblur")
query = "SELECT user_id, feed_id, is_trained FROM reader_usersubscription"
data = dbGetQuery(db, query)

common_users_by_id <- function(feed1, feed2) {
    subs1 <- subset(data, feed_id=feed1)
    subs2 <- subset(data, feed_id=feed2)
    subs_sameset <- intersect(subs1['user_id'],
                              subs2['user_id'])
    if (length(subs_sameset) > 0) {
        NA
    } else {
        subs_sameset
    }
}

