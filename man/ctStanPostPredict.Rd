% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ctStanPostPredict.R
\name{ctStanPostPredict}
\alias{ctStanPostPredict}
\title{Compares model implied density and values to observed, for a ctStanFit object.}
\usage{
ctStanPostPredict(fit, legend = TRUE, diffsize = 1, jitter = 0.02,
  wait = TRUE, probs = c(0.025, 0.5, 0.975), shading = TRUE,
  datarows = "all", nsamples = 500, ...)
}
\arguments{
\item{fit}{ctStanFit object.}

\item{legend}{Logical, whether to plot a legend.}

\item{diffsize}{Integer > 0. Number of discrete time lags to use for data viz.}

\item{jitter}{Positive numeric between 0 and 1, if TRUE, jitters empirical data by specified proportion of std dev.}

\item{wait}{Logical, if TRUE, waits for input before plotting next plot.}

\item{probs}{Vector of length 3 containing quantiles to plot -- should be rising numeric values between 0 and 1.}

\item{shading}{Logical -- show smoothed shading over generated data points? Otherwise, plot shaded polygon based on quantile estimate. 
Shading is better for non-linearities.}

\item{datarows}{integer vector specifying rows of data to plot. Otherwise 'all' uses all data.}

\item{nsamples}{Number of datasets to generate for comparisons.}

\item{...}{extra arguments to pass to plot function.}
}
\value{
If plot=FALSE, an array containing quantiles of generated data. If plot=TRUE, nothing, only plots.
}
\description{
Compares model implied density and values to observed, for a ctStanFit object.
}
\details{
This function relies on the data generated during each iteration of fitting to approximate the
model implied distributions -- thus, when limited iterations are available, the approximation will be worse.
}
\examples{
\donttest{
ctStanPostPredict(ctstantestfit,wait=FALSE, shading=FALSE, datarows=1:25,diffsize=2)
}
}
