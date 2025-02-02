
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- [![Build Status](https://travis-ci.org/cdriveraus/ctsem.svg?branch=master)](https://travis-ci.org/cdriveraus/ctsem) -->

**See the NEWS file for recent updates\!**

ctsem allows for easy specification and fitting of a range of continuous
and discrete time dynamic models, including multiple indicators (dynamic
factor analysis), multiple, potentially higher order processes, and time
dependent (varying within subject) and time independent (not varying
within subject) covariates. Classic longitudinal models like latent
growth curves and latent change score models are also possible. Version
1 of ctsem provided SEM based functionality by linking to the OpenMx
software, allowing mixed effects models (random means but fixed
regression and variance parameters) for multiple subjects. For version 2
of the R package ctsem, we include a hierarchical specification and
fitting routine that uses the Stan probabilistic programming language,
via the rstan package in R. This allows for all parameters of the
dynamic model to individually vary, using an estimated population mean
and variance, and any time independent covariate effects, as a prior.
Version 3 allows for state dependencies in the parameter specification
(i.e. time varying parameters). ctsem V1 is documented in a JSS
publication (Driver, Voelkle, Oud, 2017), and in R vignette form at
<https://cran.r-project.org/package=ctsem/vignettes/ctsem.pdf> .While
the more recent updates are outlined at
<https://github.com/cdriveraus/ctsem/raw/master/vignettes/hierarchicalmanual.pdf>
. To cite ctsem please use the citation(“ctsem”) command in R.

### To install the github version, use:

``` r
source(file = 'https://github.com/cdriveraus/ctsem/raw/master/installctsem.R')
```

### Troubleshooting Rstan / Rtools install for Windows:

Ensure recent version of R and Rtools is installed. If the
installctsem.R code has never been run before, be sure to run that (see
above).

Make sure these lines exist in home/.R/makevars.win :

    CXX14FLAGS=-O3 -mtune=native
    CXX11FLAGS=-O3 -mtune=native
    CXX14 = $(BINPREF)g++ -m$(WIN) -std=c++1y

If makevars does not exist, re-run the install code above.

In case of compile errors like `g++ not found`, ensure the devtools
package is installed:

``` r
install.packages('devtools')
```

and include the following in your .Rprofile, replacing c:/Rtools with
the appropriate path – sometimes Rbuildtools/3.5/ .

``` r
library(devtools)
Sys.setenv(PATH = paste("C:/Rtools/bin", Sys.getenv("PATH"), sep=";"))
Sys.setenv(PATH = paste("C:/Rtools/mingw_64/bin", Sys.getenv("PATH"), sep=";"))
Sys.setenv(BINPREF = "C:/Rtools/mingw_$(WIN)/bin/")
```
