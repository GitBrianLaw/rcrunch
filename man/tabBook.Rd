% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tab-book.R
\name{tabBook}
\alias{tabBook}
\title{Compute a Tab Book}
\usage{
tabBook(multitable, dataset, weight = crunch::weight(dataset),
  format = c("json", "xlsx"), file, ...)
}
\arguments{
\item{multitable}{a \code{Multitable} object}

\item{dataset}{CrunchDataset, which may have been subsetted with a filter
expression on the rows and a selection of variables on the columns.}

\item{weight}{a CrunchVariable that has been designated as a potential
weight variable for \code{dataset}, or \code{NULL} for unweighted results.
Default is the currently applied \code{\link{weight}}.}

\item{format}{character export format: currently supported values are "json"
(default) and "xlsx".}

\item{file}{character local filename to write to. A default filename will be
generated from the \code{multitable}'s name if one is not supplied and the
"xlsx" format is requested. Not required for "json" format export.}

\item{...}{Additional "options" passed to the tab book POST request.}
}
\value{
If "json" format is requested, the function returns an object of
class \code{TabBookResult}, containing a list of \code{MultitableResult}
objects, which themselves contain \code{CrunchCube}s. If "xlsx" is requested,
the function invisibly returns the filename (\code{file}, if specified, or the
the autogenerated file name). If you request "json" and wish to access the
JSON data underlying the \code{TabBookResult}, pass in a path for \code{file}
and you will get a JSON file written there as well.
}
\description{
This function allows you to generate a tab book from a multitable and data.
As with other functions, you can select the rows and columns you want to
work with by subsetting the \code{dataset} you pass into the function.
}
\details{
By specifying a "json" \code{format}, instead of generating an Excel
workbook, you'll get a TabBookResult object, containing nested CrunchCube
results. You can then further format these and construct custom tab reports.
}
\examples{
\dontrun{
m <- newMultitable(~ gender + age4 + marstat, data=ds)
tabBook(m, ds[ds$income > 1000000,], format="xlsx", file="wealthy-tab-book.xlsx")
book <- tabBook(m, ds) # Returns a TabBookResult
tables <- prop.table(book, 2)
}
}
