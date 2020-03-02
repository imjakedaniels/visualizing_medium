library(rvest) # for reading html
library(tidyverse) # for querying/manipulating/cleaning
library(lubridate) # for manipulating dates
library(purrr) # for iterating the scraper over list
library(curl)
library(xml2)

###### This is your input. ######
###### Fill this out first ######

tag <- "election-2020"  # ex. "artificial-intelligence", "true-crime", "writing"
start <- as.Date("2020-01-26") # YEAR-MO-DA ex. 2019-01-31
end <- as.Date("2020-02-01")

###### This is the script ######

url <- paste0("https://medium.com/tag/", tag, "/archive/")
timevalues <- str_replace_all(seq(start, end, by = 1), "-", "/")

unitedata <- function(x){
  full_url <- paste0(url, x)
  full_url
}

finalurl <- unitedata(timevalues)

##### NO TOUCH
##### PLEASE
mediumscraper<- function(page){
  
  page_data <- page %>% 
    curl(handle = new_handle("useragent" = "Mozilla/5.0")) %>%
    read_html() %>%
    html_nodes("div.js-postStream.u-marginTop25") 
  
  title <- page_data %>%
    html_nodes('.js-trackPostScrolls') %>%
    html_node('h3') %>% 
    html_text() %>% as.data.frame()
  
  date <- page %>% 
    str_extract('[0-9]+/[0-9]+/[0-9]+$') %>% 
    as.data.frame()
  
  author <- page_data %>%
    html_nodes('.postMetaInline .u-flexCenter') %>%
    html_node('.u-accentColor--textNormal:nth-child(1)') %>% 
    html_text() %>% as.data.frame()
  
  claps <- page_data %>%
    html_nodes('span.u-relative.u-background.js-actionMultirecommendCount.u-marginLeft5') %>% 
    html_node('button') %>% 
    html_text() %>% as.data.frame()
  
  reading_time <- page_data %>% 
    html_nodes('div.postMetaInline.postMetaInline-authorLockup.ui-captionStrong.u-flex1.u-noWrapWithEllipsis') %>% 
    html_node('.readingTime') %>% 
    html_attr('title') %>% as.data.frame()
  
  url <- page_data %>% 
    html_nodes('div.postMetaInline.postMetaInline-authorLockup.ui-captionStrong.u-flex1.u-noWrapWithEllipsis') %>%
    html_nodes('a.link.link--darken') %>% 
    html_attr('data-action-value') %>% 
    as.data.frame() %>%
    filter(str_detect(`.`,"-$")) 
  
  chart <- cbind(title, date, claps, author, reading_time, url)
  names(chart) <- c("title", "date", "claps", "author", "reading_time", "url")
  chart <- as.tibble(chart)
  return(chart)
  Sys.sleep(3)
}

data <- map_df(finalurl, mediumscraper)

cleaned_data <- data %>%
  filter(!is.na(title)) %>%
  mutate_if(is.factor, as.character) %>%
  mutate(claps = case_when(
    str_detect(claps, "K") == TRUE & .$claps %>% nchar() == 2 ~ str_replace(claps, "K", "000"),
    str_detect(claps, "K") == TRUE & .$claps %>% nchar() > 2 ~ str_remove(str_replace(claps, "K", "00"), "\\."),
    TRUE ~ claps),
    claps = as.numeric(claps),
    claps = ifelse(is.na(claps), 0, claps),
    date = as.Date(date),
    reading_time = as.numeric(str_extract(reading_time, "^[0-9]+")))

read_post <- function(x){
  tryCatch(
    read_html(x, options = "NOERROR") %>%
      html_nodes("article") %>%
      html_text(),
    error = function(e){NA}, 
    warning  = function(w){NA}
  )
}

full_data_cleaned <- cleaned_data %>%
  mutate(full_text = map(url, read_post))

full_data_cleaned_2 <- full_data_cleaned %>%
  filter(lengths(full_text) > 0) %>%
  mutate(full_text = flatten_chr(full_text),
         full_text = str_replace_all(full_text, "[:punct:]", " ")) 


write_csv(full_data_cleaned_2, paste0(cleaned_data$date %>% yday() %>% unique() %>% length(),"-Days_of_",tag,"_articles_starting_", start,".csv"))
