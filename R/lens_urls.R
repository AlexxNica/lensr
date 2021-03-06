#' @title Generate urls to search the Lens Patent Database
#' @description This function builds urls to search the Lens patent database. It is used internally in the lens_search() function. The default search groups documents by family and will return up to 50 results per page. The maximum number of results that can be retrieved is 500 (10 pages). For larger results sets use the free Lens online Collection facility to download upto 10,000 records. See details for information on the use of ranking and date measures to sort the data.
#' @param query A search string or vector of search terms (quoted)
#' @param boolean Select the type of boolean ("OR" or "AND") where using multiple search terms.
#' @param type Either fulltext (default), title, abstract, claims, or "tac" for 'title or abstract or claims' (quoted).
#' @param applicant An applicant name or vector of applicant names
#' @param applicant_boolean "AND" or "OR".
#' @param inventor An inventor name or vector of inventor names.
#' @param inventor_boolean "AND" or "OR".
#' @param publn_date_start Publication date limit to start at as YYYMMDD (numeric).
#' @param publn_date_end Publication date limit to end at as YYYMMDD (numeric).
#' @param filing_date_start Filing date limit to start at as YYYMMDD (numeric).
#' @param filing_date_end Filing date limit to end at as YYYMMDD (numeric).
#' @param rank_citing Whether to sort the Lens results by the top citing
#'   (descending). Useful for retrieving important documents. See details.
#' @param rank_family Whether to sort the Lens results by the number of family
#'   members (descending). Useful for retrieving important documents. See
#'   details.
#' @param rank_sequences Rank results on whether the documents contain a dna or amino
#'   acid sequence. See details.
#'   #' @param rank_earliest_publn Rank the results by the earliest publication date (earliest publshed).
#' @param rank_earliest_publn Rank the results by the latest publication date (most recently published).
#' @param rank_latest_publn Rank the results by the latest publication date (most recently published).
#' @param rank_earliest_filing Rank the results by the earliest filing date.
#' @param rank_latest_filing Rank the results by the latest filing date.
#' @param jurisdiction Limit the search to a single jurisdiction (default is
#'   all) e.g. "US" or choose inbuilt group "main" for the United States (US),
#'   European Patent Office (EP), Japan (JP) or the World Intellectual Property
#'   Organization (WO) for the Patent Cooperation Treaty.
#' @param families Either return the publication count and family numbers or if
#'   TRUE (default) return the patent families (deduplicates a set of
#'   publications to the first publication of the root "priority" or first
#'   filing).
#' @param results The number of results to return, either 50 or 500 (maximum).
#' @param stemming Word stemming is set to FALSE by default.
#' @param timer Where retrieving over 50 results, the delay between sending requests to the Lens (default is 20 seconds, used internally by ops_iterate()).
#' @details Only one ranking measure may be used per query. For example, it is
#'   possible to rank by family scores but not family scores and latest
#'   publications or earliest publications. The suggested work flow is to
#'   retrieve the latest publications, then rank by family and then rank_citing.
#'   This will allow the most recent and the most important documents to be
#'   retrieved in three steps for a given query.
#' @note The default connector between fields e.g. key terms and applicants and inventors is "AND".
#' @return a data.frame or tibble
#' @export
#' @importFrom xml2 read_html
#' @importFrom rvest html_nodes
#' @importFrom rvest html_text
#' @importFrom stringr str_replace_all
#' @importFrom stringr str_trim
#' @importFrom tibble as_tibble
#' @examples \dontrun{lens_urls("synthetic biology")}
#' @examples \dontrun{lens_urls(synbio, boolean = "OR", families = TRUE)}
#' @examples \dontrun{lens_urls(synbio, boolean = "AND")}
#' @examples \dontrun{lens_urls(synbio, boolean = "OR", type = "title", rank_family = TRUE)}
#' @examples \dontrun{lens_urls(synbio, boolean = "OR", type = "abstract", rank_family = TRUE)}
#' @examples \dontrun{lens_urls(synbio, boolean = "OR", type = "tac", rank_family = TRUE)}
#' @examples \donrun{lens_urls(synbio, boolean = "OR", type = "tac", rank_citing = TRUE)}
lens_urls <- function(query, boolean = "NULL", type = "NULL", applicant = NULL, applicant_boolean = "NULL", inventor = NULL, inventor_boolean = "NULL", publn_date_start = NULL, publn_date_end = NULL, filing_date_start = NULL, filing_date_end = NULL, rank_family = "NULL", rank_citing = "NULL", rank_sequences = "NULL", rank_latest_publn = "NULL", rank_earliest_publn = "NULL", rank_latest_filing = "NULL", rank_earliest_filing = "NULL", jurisdiction = "NULL", families = "NULL", timer = 20, results = NULL, stemming = FALSE){
  baseurl <- "https://www.lens.org/lens/search?q="
  # To add document_type="NULL"
  # add patent type searches (use lens name) and use applications and grants as default
  # add multi jurisdiction type
  # add partial date ranges to the search string e.g for year ranges.
  # add languages, e.g. english <- "&l=en"
  # Add stemming on off &st=false default is as is below
  # Format the query string depending on presence of spaces, length & boolean choices
  length <- length(query)
  if(length == 1){
    query <- stringr::str_replace_all(query, " ", "+")
  }
  if(length > 1){
    query <- stringr::str_replace_all(query, " ", "+")
  }
  if(boolean == "OR"){
    query <- stringr::str_c(query, collapse = "%22+%7C%7C+%22")
  }
  if(boolean == "AND"){
    query <- stringr::str_c(query, collapse = "%22+%26%26+%22")
  }
  if(type == "NULL"){
    query <- paste0("%22", query, "%22")
  }
  if(type == "title"){
    query <- paste0("title%3A%28%22", query, "%22%29")
  }
  if(type == "abstract"){
    query <- paste0("abstract", "%3A%28%22", query, "%22%29")
  }
  if(type == "claims"){
    query <- paste0("claims", "%3A%28%22", query, "%22%29")
  }
  if(type == "fulltext"){
    query <- paste0("%22", query, "%22")
  }
  if(type == "tac") {
    query <- paste0("%28title%3A%28%22", query, "%22%29+%7C%7C+abstract%3A%28%22", query, "%22%29+%7C%7C+claims%3A%28%22", query, "%22%29%29")
  }
  # applicant controls
  if(!is.null(applicant)){
    applicants_string <- applicants_url(applicant = applicant, applicant_boolean = applicant_boolean)
    connector_str <- "+%26%26+"
    query <- paste0(query, connector_str, applicants_string)
  }
  # inventor controls
  if(!is.null(inventor)){
    inventor_string <- inventors_url(inventor = inventor, inventor_boolean = inventor_boolean)
    connector_str <- "+%26%26+"
    query <- paste0(query, connector_str, inventor_string)
  }
  # full date sequence
  if(is.numeric(publn_date_start)){
    query <- paste0(query, "&dates=%2Bpub_date%3A", publn_date_start)
  }
  if(is.numeric(publn_date_end)){
    query <- paste0(query, "-", publn_date_end)
  }
  if(is.numeric(filing_date_start)){
    query <- paste0(query, "&dates=%2Bfiling_date%3A", filing_date_start)
  }
  if(is.numeric(filing_date_end)){
    query <- paste0(query, "-", filing_date_end)
  }
  # Add ranking arguments to the search string
  if(rank_citing == TRUE){
    rank_citing <- "&s=citing_pub_key_count&d=-"
    query <- paste0(query, rank_citing)
  }
  if(rank_family == TRUE){
    rank_family <- "&s=simple_family_size&d=-"
    query <- paste0(query, rank_family)
  }
  if(rank_sequences == TRUE){
    rank_sequences <- "&s=sequence_count&d=-"
    query <- paste0(query, rank_sequences)
  }
  if(rank_latest_publn == TRUE){
    latest_publication <- "&s=pub_date&d=-"
    query <- paste0(query, latest_publication)
  }
  if(rank_earliest_publn == TRUE){
    earliest_publication <- "&s=pub_date&d=%2B"
    query <- paste0(query, earliest_publication)
  }
  if(rank_latest_filing == TRUE){
    latest_filing <- "&s=filing_date&d=-"
    query <- paste0(query, latest_filing)
  }
  if(rank_earliest_filing == TRUE){
    earliest_filing <- "&s=filing_date&d=%2B"
    query <- paste0(query, earliest_filing)
  }
 # Add jurisdiction
  # Restricted to single or predefined groups at present.
length_jur <- nchar(jurisdiction)
  if(!is.null(jurisdiction) && length_jur == 2){
    # &jo=true&j=US
    jur <- "&jo=true&j="
    query <- paste0(query, jur, jurisdiction)
  }
  # if(!is.null(jurisdiction) && length_jur >=4){
  #   start <- "&jo=true"
  #   connect <- "&j="
  #   query <- paste0(query, start, jurisdiction, collapse = "&j=")
  # }
 if(!is.null(jurisdiction) && jurisdiction == "main"){
       jur <- "&jo=true&j=EP&j=JP&j=US&j=WO"
       query <- paste0(query, jur)
       }
 if(!is.null(jurisdiction) && jurisdiction == "ops"){
   jur <- "&jo=true&j=AT&j=CA&j=CH&j=EP&j=GB&j=WO"
   query <- paste0(query, jur)
   }
  # Families control (for URL)
  if(families == TRUE){
    families_string <- "&f=true"
    query <- paste0(query, families_string)
  }
  # Add stemming control
  if(stemming == FALSE){
  stemming <- "&st=false"
  query <- paste0(query, stemming)
  }
  # create consistent default for number of results where <= 50 or NULL.
  if(is.null(results)){
    baseurl <- "https://www.lens.org/lens/search?q="
    fifty <- "&n=50"
    query <- paste0(baseurl, query, fifty)
  } else if(results == 50){
    baseurl <- "https://www.lens.org/lens/search?q="
    fifty <- "&n=50"
    query <- paste0(baseurl, query, fifty)
    # where less than 50, call page of 50 anyway
  } else if(results < 50){
    baseurl <- "https://www.lens.org/lens/search?q="
    fifty <- "&n=50"
    query <- paste0(baseurl, query, fifty)
  }
  # adding pages url. Lens starts counting at 0 pages, use ceiling and -1
  if(!is.null(results) && results > 50){
     if(results <= 500){
       message("returning values specified in results", appendLF = TRUE)
       baseurl_pages <- "https://www.lens.org/lens/search?p="
       q <- "&q="
       fifty <- "&n=50"
       total <- ceiling(results / 50) - 1
       query <- paste0(baseurl_pages, seq(0, as.numeric(total)), q, query, fifty)
     }
     if(results > 500 && results > 500){
       message("More than 500 families, only 500 can be returned. Try using date ranges in lens_count to break the data into chunks of 500 or less", appendLF = TRUE)
     }
  }
   query
}