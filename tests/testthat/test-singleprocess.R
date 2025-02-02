if(.Machine$sizeof.pointer != 4){
require(ctsem)
require(testthat)

context("singleprocess")

test_that("singleprocess + reshape", {
set.seed(4)
Tpoints<-10
n.manifest=1
nsubjects=20
n.latent=1
burnin=4

DRIFT=matrix(c(-.3), nrow=n.latent, ncol=n.latent)
dtmat=matrix(exp(rnorm(Tpoints-1+burnin,.3,.1)),byrow=TRUE,nrow=nsubjects,ncol=Tpoints-1+burnin)
genm=ctModel(Tpoints=Tpoints,
  n.latent=n.latent, n.manifest=n.manifest,
  LAMBDA=matrix(c(1), nrow=n.manifest, ncol=n.latent),
  DRIFT=DRIFT,
  T0MEANS=matrix(3),
  MANIFESTTRAITVAR=diag(.4,1),
  T0VAR=matrix(6),
  DIFFUSION=matrix(c(2), byrow=TRUE, nrow=n.latent, ncol=n.latent),
  MANIFESTVAR=matrix(c(2), nrow=n.manifest, ncol=n.manifest))

cd=ctGenerate(ctmodelobj=genm, n.subjects=nsubjects, burnin=burnin, dtmean=1, 
  wide=TRUE,dtmat = dtmat)

long=ctWideToLong(datawide = cd,Tpoints = Tpoints,n.manifest = n.manifest)
long=ctDeintervalise(datalong = long)
wide=ctLongToWide(datalong = long,id='id',time='time',manifestNames= genm$manifestNames)
wide=ctIntervalise(datawide = wide,Tpoints = Tpoints,n.manifest = n.manifest)

sm<-ctModel(Tpoints=Tpoints,type='stanct',
  n.latent=n.latent,n.manifest=n.manifest,
  CINT=matrix('cint'),
  MANIFESTVAR=diag(2,1),
  MANIFESTMEANS=matrix(0),
  LAMBDA=diag(1,n.manifest))


sf=ctStanFit(datalong=long,ctstanmodel=sm,nopriors=TRUE,
  control=list(max_treedepth=8),
  iter=300,chains=2,plot=FALSE,fit=TRUE,optimize=TRUE)


m<-ctModel(Tpoints=Tpoints,type='omx',
  n.latent=n.latent,n.manifest=n.manifest,
  CINT=matrix('cint'),
  MANIFESTVAR=diag(2,1),
  TRAITVAR='auto',
  MANIFESTMEANS=matrix(0),
  LAMBDA=diag(1,n.manifest))

f=ctFit(dat=wide,ctmodelobj=m)
# summary(f)$ctparameters

# stantraitvar <- (-1/(sfsum$popmeans[2,1])) %*% sfsum$popsd[2,1]^2 %*% (-1/(sfsum$popmeans[2,1]))

#check drift using different fit approaches
expect_equal(mean(sf$stanfit$transformedpars$DRIFT[,,1,1]),summary(f)$ctparameters[2,1],tolerance=1e-1)

})

}
