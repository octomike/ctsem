
functions{


   matrix covsqrt2corsqrt(matrix mat, int invert){ //converts from unconstrained lower tri matrix to cor
    matrix[rows(mat),cols(mat)] o;
    vector[rows(mat)] s;
    o=mat;
  
    for(i in 1:rows(o)){ //set upper tri to lower
      for(j in min(i+1,rows(mat)):rows(mat)){
        real tmp = inv_logit(mat[j,i])*2-1;  // can change cor prior here
        o[j,i] = tmp;
        o[i,j] = tmp;
      }
      o[i,i]=1; // change to adjust prior for correlations
    }
  
    if(invert==1) o = inverse(o);
  
    for(i in 1:rows(o)){
      s[i] = inv_sqrt(o[i,] * o[,i]);
      if(is_inf(s[i])) s[i]=0;
    }
    o= diag_pre_multiply(s,o);
    return o;
  }



  int[] checkoffdiagzero(matrix M){
    int z[rows(M)];
    for(i in 1:rows(M)){
      z[i] = 0;
      for(j in 1:cols(M)){
        if(i!=j){
          if(M[i,j] != 0){
            z[i] = 1;
            break;
          }
        }
      }
      if(z[i]==0){ //check rows
        for(j in 1:rows(M)){
          if(i!=j){
            if(M[j,i] != 0){
              z[i] = 1;
              break;
            }
          }
        }
      }
    }
  return z;
  }

  matrix expm2(matrix M){
    matrix[rows(M),rows(M)] out;
    int z[rows(out)] = checkoffdiagzero(M);
    int z1[sum(z)];
    int z0[rows(M)-sum(z)];
    int cz1 = 1;
    int cz0 = 1;
    for(i in 1:rows(M)){
      if(z[i] == 1){
        z1[cz1] = i;
        cz1 += 1;
      }
      if(z[i] == 0){
        z0[cz0] = i;
        cz0 += 1;
      }
    }
    if(size(z1) > 0) out[z1,z1] = matrix_exp(M[z1,z1]);
    out[z0,] = rep_matrix(0,size(z0),rows(M));
    out[,z0] = rep_matrix(0,rows(M),size(z0));
    for(i in 1:size(z0)) out[z0[i],z0[i]] = exp(M[z0[i],z0[i]]);
    return out;
  }
      
  matrix sdcovsqrt2cov(matrix mat){ //converts from lower partial sd and diag sd to cov or cholesky cov
    return(tcrossprod(diag_pre_multiply(diagonal(mat),covsqrt2corsqrt(mat, 0))));
  }
      

  matrix kron_prod(matrix mata, matrix matb){
    int m=rows(mata);
    int p=rows(matb);
    int n=cols(mata);
    int q=cols(matb);
    matrix[rows(mata)*rows(matb),cols(mata)*cols(matb)] out;
    for (k in 1:p){
      for (l in 1:q){
        for (i in 1:m){
          for (j in 1:n){
            out[ p*(i-1)+k, q*(j-1)+l ] = mata[i, j] * matb[k, l];
          }
        }
      }
    }
    return out;
  }

  matrix cov_of_matrix(matrix mat){
    vector[cols(mat)] means;
    matrix[rows(mat), cols(mat)] centered;
    matrix[cols(mat), cols(mat)] covm;
    for (coli in 1:cols(mat)){
      means[coli] = mean(mat[,coli]);
      for (ri in 1:rows(mat))  {
        centered[ri,coli] = mat[ri,coli] - means[coli];
      }
    }
    covm = crossprod(centered) / (rows(mat)-1);
    for(j in 1:rows(covm)){
      covm[j,j] +=  1e-6;
    }
    return covm; 
  }

  vector colMeans(matrix mat){
    vector[cols(mat)] out;
    for(i in 1:cols(mat)){
      out[i] = mean(mat[,i]);
    }
    return out;
  }

  matrix crosscov(matrix a, matrix b){
    matrix[rows(a),cols(a)] da;
    matrix[rows(b),cols(b)] db;
    matrix[cols(a),cols(b)] out;
  
    da = a - rep_matrix( (colMeans(a))',rows(a));
    db = b - rep_matrix( (colMeans(b))',rows(b));
    out = da' * db ./ (rows(a)-1.0);
    return out;
  }

  matrix makesym(matrix mat){
    matrix[rows(mat),cols(mat)] out;
    for(coli in 1:cols(mat)){
      out[coli,coli] = mat[coli,coli] + 1e-5;
      for(rowi in coli:rows(mat)){
        if(rowi > coli) {
          out[rowi,coli] = mat[rowi,coli]; //(mat[coli,rowi] + ) *.5;
          out[coli,rowi] = mat[rowi,coli];
        }
      }
    }
    return out;
  }

  real tform(real param, int transform, data real multiplier, data real meanscale, data real offset){
    real out;
  
      if(transform==0) out = param * meanscale * multiplier + offset; 

  if(transform==1) out = log(1+(exp(param * meanscale))) * multiplier + offset ; 

  if(transform==2) out = exp(param * meanscale) * multiplier + offset; 

  if(transform==3) out = inv_logit(param*meanscale) * multiplier + offset; 

  if(transform==4) out = ((param*meanscale)^3)*multiplier + offset; 



    return out;
  }

}
data {
  int<lower=0> ndatapoints;
  int<lower=1> nmanifest;
  int<lower=1> nlatent;
  int<lower=1> nsubjects;
  int<lower=0> ntipred; // number of time independent covariates
  int<lower=0> ntdpred; // number of time dependent covariates

  matrix[ntipred ? nsubjects : 0, ntipred ? ntipred : 0] tipredsdata;
  int nmissingtipreds;
  int ntipredeffects;
  real<lower=0> tipredsimputedscale;
  real<lower=0> tipredeffectscale;
  
  
  vector[nmanifest] Y[ndatapoints];
  int nopriors;
  int lineardynamics;
  vector[ntdpred] tdpreds[ntdpred ? ndatapoints : 0];
  
  real dT[ndatapoints]; // time intervals
  real dTsmall[ndatapoints];
  int binomial; //binary data only
  int integrationsteps[ndatapoints] ; // time steps needed between time intervals for integration
  int subject[ndatapoints];
  int<lower=0> nparams;
  int T0check[ndatapoints]; // logical indicating which rows are the first for each subject
  int continuoustime; // logical indicating whether to incorporate timing information
  int nindvarying; // number of subject level parameters that are varying across subjects
  int nindvaryingoffdiagonals; //number of off diagonal parameters needed for popcov matrix
  int indvaryingindex[nindvarying];
  vector[nindvarying] sdscale;

  int nt0varstationary;
  int nt0meansstationary;
  int t0varstationary [nt0varstationary, 2];
  int t0meansstationary [nt0meansstationary, 2];

  int nobs_y[ndatapoints];  // number of observed variables per observation
  int whichobs_y[ndatapoints, nmanifest]; // index of which variables are observed per observation
  int ndiffusion; //number of latents involved in covariance calcs
  int derrind[ndiffusion]; //index of which latent variables are involved in covariance calculations

  int manifesttype[nmanifest];
  int nbinary_y[ndatapoints];  // number of observed binary variables per observation
  int whichbinary_y[ndatapoints, nmanifest]; // index of which variables are observed and binary per observation
  int ncont_y[ndatapoints];  // number of observed continuous variables per observation
  int whichcont_y[ndatapoints, nmanifest]; // index of which variables are observed and continuous per observation
  
  int intoverpop;
  int ukf;
  real ukfspread;
  int ukffull;
  int nlmeasurement;
  int intoverstates;
  int verbose; //level of printing during model fit

  int T0MEANSsubindex[nsubjects];
int LAMBDAsubindex[nsubjects];
int DRIFTsubindex[nsubjects];
int DIFFUSIONsubindex[nsubjects];
int MANIFESTVARsubindex[nsubjects];
int MANIFESTMEANSsubindex[nsubjects];
int CINTsubindex[nsubjects];
int T0VARsubindex[nsubjects];
int TDPREDEFFECTsubindex[nsubjects];
int PARSsubindex[nsubjects];
int asymCINTsubindex[nsubjects];
int asymDIFFUSIONsubindex[nsubjects];
  int T0MEANSsetup_rowcount;
int LAMBDAsetup_rowcount;
int DRIFTsetup_rowcount;
int DIFFUSIONsetup_rowcount;
int MANIFESTVARsetup_rowcount;
int MANIFESTMEANSsetup_rowcount;
int CINTsetup_rowcount;
int T0VARsetup_rowcount;
int TDPREDEFFECTsetup_rowcount;
int PARSsetup_rowcount;
  int T0MEANSsetup[T0MEANSsetup_rowcount,6 ];
int LAMBDAsetup[LAMBDAsetup_rowcount,6 ];
int DRIFTsetup[DRIFTsetup_rowcount,6 ];
int DIFFUSIONsetup[DIFFUSIONsetup_rowcount,6 ];
int MANIFESTVARsetup[MANIFESTVARsetup_rowcount,6 ];
int MANIFESTMEANSsetup[MANIFESTMEANSsetup_rowcount,6 ];
int CINTsetup[CINTsetup_rowcount,6 ];
int T0VARsetup[T0VARsetup_rowcount,6 ];
int TDPREDEFFECTsetup[TDPREDEFFECTsetup_rowcount,6 ];
int PARSsetup[PARSsetup_rowcount,6 ];
  matrix[T0MEANSsetup_rowcount, 5] T0MEANSvalues;
matrix[LAMBDAsetup_rowcount, 5] LAMBDAvalues;
matrix[DRIFTsetup_rowcount, 5] DRIFTvalues;
matrix[DIFFUSIONsetup_rowcount, 5] DIFFUSIONvalues;
matrix[MANIFESTVARsetup_rowcount, 5] MANIFESTVARvalues;
matrix[MANIFESTMEANSsetup_rowcount, 5] MANIFESTMEANSvalues;
matrix[CINTsetup_rowcount, 5] CINTvalues;
matrix[T0VARsetup_rowcount, 5] T0VARvalues;
matrix[TDPREDEFFECTsetup_rowcount, 5] TDPREDEFFECTvalues;
matrix[PARSsetup_rowcount, 5] PARSvalues;
  int TIPREDEFFECTsetup[nparams, ntipred];
  int nmatrixslots;
  int popsetup[nmatrixslots,6];
  real popvalues[nmatrixslots,5];
  int savescores;
  int gendata;
}
      
transformed data{
  matrix[nlatent,nlatent] IIlatent;
  matrix[nlatent*nlatent,nlatent*nlatent] IIlatent2;
  matrix[intoverpop ? nlatent + nindvarying : nlatent, intoverpop ? nlatent + nindvarying : nlatent] IIlatentpop;
  int nlatentpop;
  real k;
  real asquared;
  real l;
  real sqrtukfadjust;

  nlatentpop = intoverpop ? nlatent + nindvarying : nlatent;
  IIlatent = diag_matrix(rep_vector(1,nlatent));
  IIlatentpop = diag_matrix(rep_vector(1,nlatentpop));
  IIlatent2 = diag_matrix(rep_vector(1,nlatent*nlatent));

  //ukf approximation parameters
  k=.5;
  asquared =  square(2.0/sqrt(0.0+nlatentpop) * ukfspread);
  l = asquared * (nlatentpop  + k) - (nlatentpop); 
  sqrtukfadjust = sqrt(0.0+nlatentpop +l);
}
      
parameters {
  vector[nparams] rawpopmeans; // population level means 

  vector[nindvarying] rawpopsdbase; //population level std dev
  vector[nindvaryingoffdiagonals] sqrtpcov;
  vector[intoverpop ? 0 : nindvarying*nsubjects] baseindparams; //vector of subject level deviations, on the raw scale
  
  vector[ntipredeffects] tipredeffectparams; // effects of time independent covariates
  vector[nmissingtipreds] tipredsimputed;
  
  vector[intoverstates ? 0 : nlatent*ndatapoints] etaupdbasestates; //sampled latent states posterior
  //real<lower=1e-5,upper=5> ukfscale;
  
}
      
transformed parameters{
  vector[nindvarying] rawpopsd; //population level std dev
  matrix[nindvarying,nindvarying] rawpopcovsqrt; 
  real ll;

  matrix[ntipred ? nsubjects : 0, ntipred ? ntipred : 0] tipreds; //tipred values to fill from data and, when needed, imputation vector
  matrix[nparams, ntipred] TIPREDEFFECT; //design matrix of individual time independent predictor effects

  if(ntipred > 0){ 
    int counter = 0;
    for(coli in 1:cols(tipreds)){ //insert missing ti predictors
      for(rowi in 1:rows(tipreds)){
        if(tipredsdata[rowi,coli]==99999) {
          counter += 1;
          tipreds[rowi,coli] = tipredsimputed[counter];
        } else tipreds[rowi,coli] = tipredsdata[rowi,coli];
      }
    }
    for(ci in 1:ntipred){ //configure design matrix
      for(ri in 1:nparams){
        if(TIPREDEFFECTsetup[ri,ci] > 0) {
          TIPREDEFFECT[ri,ci] = tipredeffectparams[TIPREDEFFECTsetup[ri,ci]];
        } else {
          TIPREDEFFECT[ri,ci] = 0;
        }
      }
    }
  }

  if(nindvarying > 0){
    int counter =0;
    rawpopsd = log(1+exp(2*rawpopsdbase)) .* sdscale;
    for(j in 1:nindvarying){
      rawpopcovsqrt[j,j] = 1;
      for(i in 1:nindvarying){
        if(i > j){
          counter += 1;
          rawpopcovsqrt[i,j]=sqrtpcov[counter];
          rawpopcovsqrt[j,i]=sqrtpcov[counter];
        }
      }
    }
    rawpopcovsqrt = diag_pre_multiply(rawpopsd, covsqrt2corsqrt(rawpopcovsqrt,0)); 
  }//end indvarying par setup

  ll=0;
{
  int si;
  int counter = 0;
  vector[nlatentpop] eta; //latent states
  matrix[nlatentpop, nlatentpop] etacov; //covariance of latent states

  //measurement 
  vector[nmanifest] err;
  vector[nmanifest] ypred;
  vector[ukf ? nmanifest : 0] ystate;
  matrix[nmanifest, nmanifest] ypredcov;
  matrix[nlatentpop, nmanifest] K; // kalman gain
  matrix[nmanifest, nmanifest] ypredcov_sqrt; 

  vector[nmanifest+nmanifest+ (savescores ? nmanifest*2+nlatent*2 : 0)] kout[ndatapoints];

  //ukf
  matrix[ukf ? nlatentpop :0,ukf ? nlatentpop :0] sigpoints;

  //linear continuous time calcs
  matrix[nlatent+1,nlatent+1] discreteDRIFT;
  vector[lineardynamics + ( 1-continuoustime)  ? nlatent : 0] discreteCINT;
  matrix[nlatent,nlatent] discreteDIFFUSION;

  //dynamic system matrices
  matrix[ T0MEANSsetup_rowcount ? max(T0MEANSsetup[,1]) : 0, T0MEANSsetup_rowcount ? max(T0MEANSsetup[,2]) : 0 ] sT0MEANS;
matrix[ LAMBDAsetup_rowcount ? max(LAMBDAsetup[,1]) : 0, LAMBDAsetup_rowcount ? max(LAMBDAsetup[,2]) : 0 ] sLAMBDA;
matrix[ DRIFTsetup_rowcount ? max(DRIFTsetup[,1]) : 0, DRIFTsetup_rowcount ? max(DRIFTsetup[,2]) : 0 ] sDRIFT;
matrix[ DIFFUSIONsetup_rowcount ? max(DIFFUSIONsetup[,1]) : 0, DIFFUSIONsetup_rowcount ? max(DIFFUSIONsetup[,2]) : 0 ] sDIFFUSION;
matrix[ MANIFESTVARsetup_rowcount ? max(MANIFESTVARsetup[,1]) : 0, MANIFESTVARsetup_rowcount ? max(MANIFESTVARsetup[,2]) : 0 ] sMANIFESTVAR;
matrix[ MANIFESTMEANSsetup_rowcount ? max(MANIFESTMEANSsetup[,1]) : 0, MANIFESTMEANSsetup_rowcount ? max(MANIFESTMEANSsetup[,2]) : 0 ] sMANIFESTMEANS;
matrix[ CINTsetup_rowcount ? max(CINTsetup[,1]) : 0, CINTsetup_rowcount ? max(CINTsetup[,2]) : 0 ] sCINT;
matrix[ T0VARsetup_rowcount ? max(T0VARsetup[,1]) : 0, T0VARsetup_rowcount ? max(T0VARsetup[,2]) : 0 ] sT0VAR;
matrix[ TDPREDEFFECTsetup_rowcount ? max(TDPREDEFFECTsetup[,1]) : 0, TDPREDEFFECTsetup_rowcount ? max(TDPREDEFFECTsetup[,2]) : 0 ] sTDPREDEFFECT;
matrix[ PARSsetup_rowcount ? max(PARSsetup[,1]) : 0, PARSsetup_rowcount ? max(PARSsetup[,2]) : 0 ] sPARS;

  matrix[nlatent,nlatent] sasymDIFFUSION; //stationary latent process variance
  vector[nt0meansstationary ? nlatent : 0] sasymCINT; // latent process asymptotic level
  

  if(lineardynamics) discreteDIFFUSION = rep_matrix(0,nlatent,nlatent); //in case some elements remain zero due to derrind

  for(rowi in 1:ndatapoints){


    matrix[ukf ? nlatentpop : 0, ukffull ? 2*nlatentpop +2 : nlatentpop + 2 ] ukfstates; //sampled states relevant for dynamics
    matrix[ukf ? nmanifest : 0 , ukffull ? 2*nlatentpop +2 : nlatentpop + 2] ukfmeasures; // expected measures based on sampled states

    si=subject[rowi];
    
    if(T0check[rowi] == 1) { // calculate initial matrices if this is first row for si

    {
  vector[nparams] rawindparams;
  vector[nparams] tipredaddition;
  vector[nparams] indvaraddition;
  
  if(si < 2 || (si > 1 && (nindvarying >0 || ntipred > 0))){ //si of 0 used
    tipredaddition = rep_vector(0,nparams);
    indvaraddition = rep_vector(0,nparams);

    if(si > 0 && nindvarying > 0 && intoverpop==0) indvaraddition[indvaryingindex] = rawpopcovsqrt * baseindparams[(1+(si-1)*nindvarying):(si*nindvarying)];
  
    if(si > 0 &&  ntipred > 0) tipredaddition = TIPREDEFFECT * tipreds[si]';
  
    rawindparams = rawpopmeans + tipredaddition + indvaraddition;
  }

  if(si <= T0MEANSsubindex[nsubjects]){
    for(ri in 1:size(T0MEANSsetup)){
      if(si==1 || T0MEANSsetup[ri,5] > 0 || T0MEANSsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sT0MEANS[T0MEANSsetup[ ri,1], T0MEANSsetup[ri,2]] = T0MEANSsetup[ri,3] ? tform(rawindparams[ T0MEANSsetup[ri,3] ], T0MEANSsetup[ri,4], T0MEANSvalues[ri,2], T0MEANSvalues[ri,3], T0MEANSvalues[ri,4] ) : T0MEANSvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= LAMBDAsubindex[nsubjects]){
    for(ri in 1:size(LAMBDAsetup)){
      if(si==1 || LAMBDAsetup[ri,5] > 0 || LAMBDAsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sLAMBDA[LAMBDAsetup[ ri,1], LAMBDAsetup[ri,2]] = LAMBDAsetup[ri,3] ? tform(rawindparams[ LAMBDAsetup[ri,3] ], LAMBDAsetup[ri,4], LAMBDAvalues[ri,2], LAMBDAvalues[ri,3], LAMBDAvalues[ri,4] ) : LAMBDAvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= DRIFTsubindex[nsubjects]){
    for(ri in 1:size(DRIFTsetup)){
      if(si==1 || DRIFTsetup[ri,5] > 0 || DRIFTsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sDRIFT[DRIFTsetup[ ri,1], DRIFTsetup[ri,2]] = DRIFTsetup[ri,3] ? tform(rawindparams[ DRIFTsetup[ri,3] ], DRIFTsetup[ri,4], DRIFTvalues[ri,2], DRIFTvalues[ri,3], DRIFTvalues[ri,4] ) : DRIFTvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= DIFFUSIONsubindex[nsubjects]){
    for(ri in 1:size(DIFFUSIONsetup)){
      if(si==1 || DIFFUSIONsetup[ri,5] > 0 || DIFFUSIONsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sDIFFUSION[DIFFUSIONsetup[ ri,1], DIFFUSIONsetup[ri,2]] = DIFFUSIONsetup[ri,3] ? tform(rawindparams[ DIFFUSIONsetup[ri,3] ], DIFFUSIONsetup[ri,4], DIFFUSIONvalues[ri,2], DIFFUSIONvalues[ri,3], DIFFUSIONvalues[ri,4] ) : DIFFUSIONvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= MANIFESTVARsubindex[nsubjects]){
    for(ri in 1:size(MANIFESTVARsetup)){
      if(si==1 || MANIFESTVARsetup[ri,5] > 0 || MANIFESTVARsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sMANIFESTVAR[MANIFESTVARsetup[ ri,1], MANIFESTVARsetup[ri,2]] = MANIFESTVARsetup[ri,3] ? tform(rawindparams[ MANIFESTVARsetup[ri,3] ], MANIFESTVARsetup[ri,4], MANIFESTVARvalues[ri,2], MANIFESTVARvalues[ri,3], MANIFESTVARvalues[ri,4] ) : MANIFESTVARvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= MANIFESTMEANSsubindex[nsubjects]){
    for(ri in 1:size(MANIFESTMEANSsetup)){
      if(si==1 || MANIFESTMEANSsetup[ri,5] > 0 || MANIFESTMEANSsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sMANIFESTMEANS[MANIFESTMEANSsetup[ ri,1], MANIFESTMEANSsetup[ri,2]] = MANIFESTMEANSsetup[ri,3] ? tform(rawindparams[ MANIFESTMEANSsetup[ri,3] ], MANIFESTMEANSsetup[ri,4], MANIFESTMEANSvalues[ri,2], MANIFESTMEANSvalues[ri,3], MANIFESTMEANSvalues[ri,4] ) : MANIFESTMEANSvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= CINTsubindex[nsubjects]){
    for(ri in 1:size(CINTsetup)){
      if(si==1 || CINTsetup[ri,5] > 0 || CINTsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sCINT[CINTsetup[ ri,1], CINTsetup[ri,2]] = CINTsetup[ri,3] ? tform(rawindparams[ CINTsetup[ri,3] ], CINTsetup[ri,4], CINTvalues[ri,2], CINTvalues[ri,3], CINTvalues[ri,4] ) : CINTvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= T0VARsubindex[nsubjects]){
    for(ri in 1:size(T0VARsetup)){
      if(si==1 || T0VARsetup[ri,5] > 0 || T0VARsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sT0VAR[T0VARsetup[ ri,1], T0VARsetup[ri,2]] = T0VARsetup[ri,3] ? tform(rawindparams[ T0VARsetup[ri,3] ], T0VARsetup[ri,4], T0VARvalues[ri,2], T0VARvalues[ri,3], T0VARvalues[ri,4] ) : T0VARvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= TDPREDEFFECTsubindex[nsubjects]){
    for(ri in 1:size(TDPREDEFFECTsetup)){
      if(si==1 || TDPREDEFFECTsetup[ri,5] > 0 || TDPREDEFFECTsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sTDPREDEFFECT[TDPREDEFFECTsetup[ ri,1], TDPREDEFFECTsetup[ri,2]] = TDPREDEFFECTsetup[ri,3] ? tform(rawindparams[ TDPREDEFFECTsetup[ri,3] ], TDPREDEFFECTsetup[ri,4], TDPREDEFFECTvalues[ri,2], TDPREDEFFECTvalues[ri,3], TDPREDEFFECTvalues[ri,4] ) : TDPREDEFFECTvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= PARSsubindex[nsubjects]){
    for(ri in 1:size(PARSsetup)){
      if(si==1 || PARSsetup[ri,5] > 0 || PARSsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sPARS[PARSsetup[ ri,1], PARSsetup[ri,2]] = PARSsetup[ri,3] ? tform(rawindparams[ PARSsetup[ri,3] ], PARSsetup[ri,4], PARSvalues[ri,2], PARSvalues[ri,3], PARSvalues[ri,4] ) : PARSvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  // perform any whole matrix transformations 
    
  if(si <= DIFFUSIONsubindex[nsubjects] && ukf==0) sDIFFUSION = sdcovsqrt2cov(sDIFFUSION);

    if(si <= asymDIFFUSIONsubindex[nsubjects]) {
      if(ndiffusion < nlatent) sasymDIFFUSION = to_matrix(rep_vector(0,nlatent * nlatent),nlatent,nlatent);

      if(continuoustime==1 && ukf==0) sasymDIFFUSION[ derrind, derrind] = to_matrix( 
      -( kron_prod( sDRIFT[ derrind, derrind ], IIlatent[ derrind, derrind ]) + 
         kron_prod(IIlatent[ derrind, derrind ], sDRIFT[ derrind, derrind ]) ) \ 
      to_vector( sDIFFUSION[ derrind, derrind ] + IIlatent[ derrind, derrind ] * 1e-5), ndiffusion,ndiffusion);

      if(continuoustime==0) sasymDIFFUSION = to_matrix( (IIlatent2 - 
        kron_prod(sDRIFT, sDRIFT)) *  to_vector(sDIFFUSION) , ndiffusion, ndiffusion);
    } //end asymdiffusion loops
          
    if(nt0meansstationary > 0){
      if(si <= asymCINTsubindex[nsubjects]){
        if(continuoustime==1) sasymCINT =  -sDRIFT \ sCINT[ ,1 ];
        if(continuoustime==0) sasymCINT =  (IIlatent - sDRIFT) \ sCINT[,1 ];
      }
    }

          
    if(binomial==0){
      if(si <= MANIFESTVARsubindex[nsubjects]) {
         for(ri in 1:nmanifest) sMANIFESTVAR[ri,ri] = square(sMANIFESTVAR[ri,ri]);
      }
    }
          
          
    if(si <= T0VARsubindex[nsubjects]) {
      if(ukf==0) sT0VAR = sdcovsqrt2cov(sT0VAR);
      if(nt0varstationary > 0) for(ri in 1:nt0varstationary){
        sT0VAR[t0varstationary[ri,1],t0varstationary[ri,2] ] = 
          sasymDIFFUSION[t0varstationary[ri,1],t0varstationary[ri,2] ];
        sT0VAR[t0varstationary[ri,2],t0varstationary[ri,1] ] = 
          sasymDIFFUSION[t0varstationary[ri,2],t0varstationary[ri,1] ];
      }
    }
    
    if(nt0meansstationary > 0){
      if(si <= T0MEANSsubindex[nsubjects]) {
        for(ri in 1:nt0meansstationary){
          sT0MEANS[t0meansstationary[ri,1] , 1] = 
            sasymCINT[t0meansstationary[ri,1] ];
        }
      }
    }
  
 }
  

      if(ukf==1){
        eta = rep_vector(0,nlatentpop); // because some values stay zero
        sigpoints = rep_matrix(0, nlatentpop,nlatentpop);
      
        if(intoverpop==1) {
          if(ntipred ==0) eta[ (nlatent+1):(nlatentpop)] = rawpopmeans[indvaryingindex];
          if(ntipred >0) eta[ (nlatent+1):(nlatentpop)] = rawpopmeans[indvaryingindex] + TIPREDEFFECT[indvaryingindex] * tipreds[si]';
        }
      }


      if(ukf==0){
      eta = sT0MEANS[,1]; //prior for initial latent state
      if(ntdpred > 0) eta += sTDPREDEFFECT * tdpreds[rowi];
      etacov =  sT0VAR;
      }

    } //end T0 matrices

    if(lineardynamics==1 && ukf==0 && T0check[rowi]==0){ //linear kf time update
    
      if(continuoustime ==1){
        int dtchange = 0;
        if(si==1 && T0check[rowi -1] == 1) {
          dtchange = 1;
        } else if(T0check[rowi-1] == 1 && dT[rowi-2] != dT[rowi]){
          dtchange = 1;
        } else if(T0check[rowi-1] == 0 && dT[rowi-1] != dT[rowi]) dtchange = 1;
        
        if(dtchange==1 || (T0check[rowi-1]==1 && si <= DRIFTsubindex[si] && si <= CINTsubindex[si])){
          discreteDRIFT = expm2(append_row(append_col(sDRIFT,sCINT),rep_matrix(0,1,nlatent+1)) * dT[rowi]);
        }
    
        if(dtchange==1 || (T0check[rowi-1]==1 && (si <= DIFFUSIONsubindex[si]|| si <= DRIFTsubindex[si]))){
          discreteDIFFUSION[derrind, derrind] = sasymDIFFUSION[derrind, derrind] - 
            quad_form( sasymDIFFUSION[derrind, derrind], discreteDRIFT[derrind, derrind]' );
          //discreteDIFFUSION[derrind, derrind] = discreteDIFFUSIONcalc(sDRIFT[derrind, derrind], sDIFFUSION[derrind, derrind], dT[rowi]);
          if(intoverstates==0) discreteDIFFUSION = cholesky_decompose(discreteDIFFUSION);
        }
      }
  
      if(continuoustime==0 && T0check[rowi-1] == 1){
        discreteDRIFT=append_row(append_col(sDRIFT,sCINT),rep_matrix(0,1,nlatent+1));
        discreteDRIFT[nlatent+1,nlatent+1] = 1;
        //discreteCINT=sCINT[,1];
        discreteDIFFUSION=sDIFFUSION;
        if(intoverstates==0) discreteDIFFUSION = cholesky_decompose(discreteDIFFUSION);
      }

      eta = (discreteDRIFT * append_row(eta,1.0))[1:nlatent];
      if(ntdpred > 0) eta += sTDPREDEFFECT * tdpreds[rowi];
      if(intoverstates==1) {
        etacov = quad_form(etacov, discreteDRIFT[1:nlatent,1:nlatent]');
        if(ndiffusion > 0) etacov += discreteDIFFUSION;
      }
    }//end linear time update


    if(ukf==1){ //ukf time update
      vector[nlatentpop] state;
      if(T0check[rowi]==0){
        matrix[nlatentpop,nlatentpop] J;
        vector[nlatent] base;
        J = rep_matrix(0,nlatentpop,nlatentpop); //dont necessarily need to loop over tdpreds here...
        if(continuoustime==1){
          matrix[nlatentpop,nlatentpop] Je;
          matrix[nlatent*2,nlatent*2] dQi;
          for(stepi in 1:integrationsteps[rowi]){
            for(statei in 0:nlatentpop){
              if(statei>0){
                J[statei,statei] = 1e-6;
                state = eta + J[,statei];
              } else {
                state = eta;
              }
              ;
;

    if(intoverpop==1){

    for(ri in 1:size(DRIFTsetup)){ //for each row of matrix setup
      if(DRIFTsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ DRIFTsetup[ ri,5]){
          sDRIFT[DRIFTsetup[ ri,1], DRIFTsetup[ri,2]] = 
            tform(state[nlatent +DRIFTsetup[ri,5] ], DRIFTsetup[ri,4], DRIFTvalues[ri,2], DRIFTvalues[ri,3], DRIFTvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(DIFFUSIONsetup)){ //for each row of matrix setup
      if(DIFFUSIONsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ DIFFUSIONsetup[ ri,5]){
          sDIFFUSION[DIFFUSIONsetup[ ri,1], DIFFUSIONsetup[ri,2]] = 
            tform(state[nlatent +DIFFUSIONsetup[ri,5] ], DIFFUSIONsetup[ri,4], DIFFUSIONvalues[ri,2], DIFFUSIONvalues[ri,3], DIFFUSIONvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(CINTsetup)){ //for each row of matrix setup
      if(CINTsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ CINTsetup[ ri,5]){
          sCINT[CINTsetup[ ri,1], CINTsetup[ri,2]] = 
            tform(state[nlatent +CINTsetup[ri,5] ], CINTsetup[ri,4], CINTvalues[ri,2], CINTvalues[ri,3], CINTvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(PARSsetup)){ //for each row of matrix setup
      if(PARSsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ PARSsetup[ ri,5]){
          sPARS[PARSsetup[ ri,1], PARSsetup[ri,2]] = 
            tform(state[nlatent +PARSsetup[ri,5] ], PARSsetup[ri,4], PARSvalues[ri,2], PARSvalues[ri,3], PARSvalues[ri,4] ); 
        }
      }
    }} //remove diffusion calcs and do elsewhere
              if(statei== 0) {
                base = sDRIFT * state[1:nlatent] + sCINT[,1];
              }
              if(statei > 0) J[1:nlatent,statei] = (( sDRIFT * state[1:nlatent] + sCINT[,1]) - base)/1e-6;
            }
            ;

            Je= expm2(J * dTsmall[rowi]) ;
            discreteDRIFT = expm2(append_row(append_col(sDRIFT,sCINT),rep_vector(0,nlatent+1)') * dTsmall[rowi]);
            sasymDIFFUSION = to_matrix(  -( kron_prod( J[1:nlatent,1:nlatent], IIlatent) +  
              kron_prod(IIlatent, J[1:nlatent,1:nlatent]) ) \ to_vector(tcrossprod(sDIFFUSION)), nlatent,nlatent);
            discreteDIFFUSION =  sasymDIFFUSION - quad_form( sasymDIFFUSION, Je[1:nlatent,1:nlatent]' );
            etacov = quad_form(etacov, Je');
            etacov[1:nlatent,1:nlatent] += discreteDIFFUSION;
            eta[1:nlatent] = (discreteDRIFT * append_row(eta[1:nlatent],1.0))[1:nlatent];
          }
        }

        if(continuoustime==0){ //need covariance in here
            for(statei in 0:nlatentpop){
              if(statei>0){
                J[statei,statei] = 1e-6;
                state = eta + J[,statei];
              } else {
                state = eta;
              }
              ;
;

    if(intoverpop==1){

    for(ri in 1:size(DRIFTsetup)){ //for each row of matrix setup
      if(DRIFTsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ DRIFTsetup[ ri,5]){
          sDRIFT[DRIFTsetup[ ri,1], DRIFTsetup[ri,2]] = 
            tform(state[nlatent +DRIFTsetup[ri,5] ], DRIFTsetup[ri,4], DRIFTvalues[ri,2], DRIFTvalues[ri,3], DRIFTvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(DIFFUSIONsetup)){ //for each row of matrix setup
      if(DIFFUSIONsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ DIFFUSIONsetup[ ri,5]){
          sDIFFUSION[DIFFUSIONsetup[ ri,1], DIFFUSIONsetup[ri,2]] = 
            tform(state[nlatent +DIFFUSIONsetup[ri,5] ], DIFFUSIONsetup[ri,4], DIFFUSIONvalues[ri,2], DIFFUSIONvalues[ri,3], DIFFUSIONvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(CINTsetup)){ //for each row of matrix setup
      if(CINTsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ CINTsetup[ ri,5]){
          sCINT[CINTsetup[ ri,1], CINTsetup[ri,2]] = 
            tform(state[nlatent +CINTsetup[ri,5] ], CINTsetup[ri,4], CINTvalues[ri,2], CINTvalues[ri,3], CINTvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(PARSsetup)){ //for each row of matrix setup
      if(PARSsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ PARSsetup[ ri,5]){
          sPARS[PARSsetup[ ri,1], PARSsetup[ri,2]] = 
            tform(state[nlatent +PARSsetup[ri,5] ], PARSsetup[ri,4], PARSvalues[ri,2], PARSvalues[ri,3], PARSvalues[ri,4] ); 
        }
      }
    }} //remove diffusion calcs and do elsewhere
              if(statei== 0) {
                base = sDRIFT * state[1:nlatent] + sCINT[,1];
              }
              if(statei > 0) J[1:nlatent,statei] = (( sDRIFT * state[1:nlatent] + sCINT[,1]) - base)/1e-6;
            }
          ;

          discreteDRIFT=append_row(append_col(sDRIFT,sCINT),rep_matrix(0,1,nlatent+1));
          discreteDRIFT[nlatent+1,nlatent+1] = 1;
          etacov = quad_form(etacov, J');
          etacov[1:nlatent,1:nlatent] += sDIFFUSION;
          if(intoverstates==0) discreteDIFFUSION = cholesky_decompose(discreteDIFFUSION);
          eta[1:nlatent] = (discreteDRIFT * append_row(eta[1:nlatent],1.0))[1:nlatent];
        }
      } // end of non t0 time update
  
  
    if(nlmeasurement==1 || ntdpred > 0 || T0check[rowi]==1){ //ukf time update
  
      if(T0check[rowi]==1) {
        if(intoverpop==1) sigpoints[(nlatent+1):(nlatentpop), (nlatent+1):(nlatentpop)] = rawpopcovsqrt * sqrtukfadjust;
        sigpoints[1:nlatent,1:nlatent] = sT0VAR * sqrtukfadjust;
      }
      
      if(T0check[rowi]==0)  sigpoints = cholesky_decompose(makesym(etacov)) * sqrtukfadjust;
    
      //configure ukf states
      for(statei in 2:cols(ukfstates) ){ //for each ukf state sample
  
          state = eta; 
          if(statei > (2+nlatentpop)){
            state += -sigpoints[,statei-(2+nlatentpop)];
          } else
          if(statei > 2) state += sigpoints[,statei-2]; 

        if(T0check[rowi]==1){
          ;
      if(intoverpop==1){
        
    for(ri in 1:size(T0MEANSsetup)){
      if(T0MEANSsetup[ ri,5] > 0){ 
         sT0MEANS[T0MEANSsetup[ ri,1], T0MEANSsetup[ri,2]] = tform(state[nlatent +T0MEANSsetup[ri,5] ], T0MEANSsetup[ri,4], T0MEANSvalues[ri,2], T0MEANSvalues[ri,3], T0MEANSvalues[ri,4] ); 
      }
    }

    for(ri in 1:size(T0VARsetup)){
      if(T0VARsetup[ ri,5] > 0){ 
         sT0VAR[T0VARsetup[ ri,1], T0VARsetup[ri,2]] = tform(state[nlatent +T0VARsetup[ri,5] ], T0VARsetup[ri,4], T0VARvalues[ri,2], T0VARvalues[ri,3], T0VARvalues[ri,4] ); 
      }
    }};
          state[1:nlatent] += sT0MEANS[,1];
        } 
        ;
        if(ntdpred > 0) state[1:nlatent] +=   (sTDPREDEFFECT * tdpreds[rowi]); //tdpred effect only influences at observed time point
        ukfstates[, statei] = state; //now contains time updated state
        if(statei==2 && ukffull==1) ukfstates[, 1] = state; //mean goes in twice for weighting
      }
  
      if(ukffull == 1) {
        eta = colMeans(ukfstates');
        etacov = cov_of_matrix(ukfstates') / asquared;
      }
      if(ukffull == 0){
        eta = ukfstates[,2];
        etacov = tcrossprod(ukfstates[,3:(nlatentpop+2)] - rep_matrix(ukfstates[,2],nlatentpop)) /asquared / (nlatentpop*2+1);
      }
    } //end ukf if necessary time update
  } // end non linear time update


  if(savescores==1) kout[rowi,(nmanifest*2+1):(nmanifest*2+nlatent)] = eta;
if(verbose > 1) print("etaprior = ", eta, " etapriorcov = ",etacov);

    if(intoverstates==0 && lineardynamics == 1) {
      if(T0check[rowi]==1) eta += cholesky_decompose(sT0VAR) * etaupdbasestates[(1+(rowi-1)*nlatent):(rowi*nlatent)];
      if(T0check[rowi]==0) eta +=  discreteDIFFUSION * etaupdbasestates[(1+(rowi-1)*nlatent):(rowi*nlatent)];
    }

    if (nobs_y[rowi] > 0) {  // if some observations create right size matrices for missingness and calculate...
    
      int o[nobs_y[rowi]]; //which indicators are observed
      int o1[nbinary_y[rowi]]; //which indicators are observed and binary
      int o0[ncont_y[rowi]]; //which indicators are observed and continuous
      o = whichobs_y[rowi,1:nobs_y[rowi]]; //which obs are not missing in this row
      o1 = whichbinary_y[rowi,1:nbinary_y[rowi]];
      o0 = whichcont_y[rowi,1:ncont_y[rowi]];

      if(nlmeasurement==0){ //non ukf measurement
        if(intoverstates==1) { //classic kalman
          ypred[o] = sMANIFESTMEANS[o,1] + sLAMBDA[o,] * eta[1:nlatent];
          if(nbinary_y[rowi] > 0) ypred[o1] = to_vector(inv_logit(to_array_1d(sMANIFESTMEANS[o1,1] +sLAMBDA[o1,] * eta[1:nlatent])));
          ypredcov[o,o] = quad_form(etacov[1:nlatent,1:nlatent], sLAMBDA[o,]') + sMANIFESTVAR[o,o];
          for(wi in 1:nmanifest){ 
            if(manifesttype[wi]==1 && Y[rowi,wi] != 99999) ypredcov[wi,wi] += fabs((ypred[wi] - 1) .* (ypred[wi]));
            if(manifesttype[wi]==2 && Y[rowi,wi] != 99999) ypredcov[wi,wi] += square(fabs((ypred[wi] - round(ypred[wi])))); 
          }
          K[,o] = mdivide_right(etacov * append_row(sLAMBDA[o,]',rep_matrix(0,nlatentpop-nlatent,nmanifest)[,o]), ypredcov[o,o]); 
          etacov += -K[,o] * append_col(sLAMBDA[o,],rep_matrix(0,nmanifest,nlatentpop-nlatent)[o,]) * etacov;
        }
        if(intoverstates==0) { //sampled states
          if(ncont_y[rowi] > 0) {
            ypred[o0] = sMANIFESTMEANS[o0,1] + sLAMBDA[o0,] * eta[1:nlatent];
            if(ncont_y[rowi] > 0) ypredcov_sqrt[o0,o0] = sMANIFESTVAR[o0,o0];
          }
          if(nbinary_y[rowi] > 0) ypred[o1] = to_vector(inv_logit(to_array_1d(sMANIFESTMEANS[o1,1] +sLAMBDA[o1,] * eta[1:nlatent])));
        }
      } 
  

      if(nlmeasurement==1){ //ukf measurement
        vector[nlatentpop] state; //dynamic portion of current states
        matrix[nmanifest,cols(ukfmeasures)] merrorstates;

        for(statei in 2:cols(ukfmeasures)){
          state = ukfstates[, statei];
          ;
      if(intoverpop==1){
        
    for(ri in 1:size(LAMBDAsetup)){
      if(LAMBDAsetup[ ri,5] > 0){ 
         sLAMBDA[LAMBDAsetup[ ri,1], LAMBDAsetup[ri,2]] = tform(ukfstates[nlatent +LAMBDAsetup[ri,5], statei ], LAMBDAsetup[ri,4], LAMBDAvalues[ri,2], LAMBDAvalues[ri,3], LAMBDAvalues[ri,4] ); 
      }
    }

    for(ri in 1:size(MANIFESTMEANSsetup)){
      if(MANIFESTMEANSsetup[ ri,5] > 0){ 
         sMANIFESTMEANS[MANIFESTMEANSsetup[ ri,1], MANIFESTMEANSsetup[ri,2]] = tform(ukfstates[nlatent +MANIFESTMEANSsetup[ri,5], statei ], MANIFESTMEANSsetup[ri,4], MANIFESTMEANSvalues[ri,2], MANIFESTMEANSvalues[ri,3], MANIFESTMEANSvalues[ri,4] ); 
      }
    }

    for(ri in 1:size(MANIFESTVARsetup)){
      if(MANIFESTVARsetup[ ri,5] > 0){ 
         sMANIFESTVAR[MANIFESTVARsetup[ ri,1], MANIFESTVARsetup[ri,2]] = tform(ukfstates[nlatent +MANIFESTVARsetup[ri,5], statei ], MANIFESTVARsetup[ri,4], MANIFESTVARvalues[ri,2], MANIFESTVARvalues[ri,3], MANIFESTVARvalues[ri,4] ); 
      }
    }

    for(ri in 1:size(PARSsetup)){
      if(PARSsetup[ ri,5] > 0){ 
         sPARS[PARSsetup[ ri,1], PARSsetup[ri,2]] = tform(ukfstates[nlatent +PARSsetup[ri,5], statei ], PARSsetup[ri,4], PARSvalues[ri,2], PARSvalues[ri,3], PARSvalues[ri,4] ); 
      }
    }};

  
          ukfmeasures[, statei] = sMANIFESTMEANS[,1] + sLAMBDA * state[1:nlatent];
          if(nbinary_y[rowi] > 0) {
            ukfmeasures[o1 , statei] = to_vector(inv_logit(to_array_1d(ukfmeasures[o1 , statei])));
          }
        
        merrorstates[,statei] = diagonal(sMANIFESTVAR);
        for(wi in 1:nmanifest){ 
          if(manifesttype[wi]==1 && Y[rowi,wi] != 99999) merrorstates[wi,statei] = sMANIFESTVAR[wi,wi] + fabs((ukfmeasures[wi,statei] - 1) .* (ukfmeasures[wi,statei])); //sMANIFESTVAR[wi,wi] + (merror[wi] / cols(ukfmeasures) +1e-8);
          if(manifesttype[wi]==2 && Y[rowi,wi] != 99999) merrorstates[wi,statei] = sMANIFESTVAR[wi,wi] + square(fabs((ukfmeasures[wi,statei]- round(ukfmeasures[wi,statei])))); 
        }
          
          if(statei==2 && ukffull == 1) { 
            merrorstates[,1] = merrorstates[,2];
            ukfmeasures[ , 1] = ukfmeasures [,2];
          }
        } 
        if(ukffull == 1) {
          ypred[o] = colMeans(ukfmeasures[o,]'); 
          ypredcov[o,o] = cov_of_matrix(ukfmeasures[o,]') /asquared + diag_matrix(colMeans(merrorstates[o,]')); //
          K[,o] = mdivide_right(crosscov(ukfstates', ukfmeasures[o,]') /asquared, ypredcov[o,o]); 
        }
        if(ukffull == 0){
          ypred[o] = ukfmeasures[o,2];
          for(ci in 3:cols(ukfmeasures)) ukfmeasures[o,ci] += -ukfmeasures[o,2];
          for(ci in 3:cols(ukfstates)) ukfstates[,ci] += -ukfstates[,2];
          ypredcov[o,o] = tcrossprod(ukfmeasures[o,3:(nlatentpop+2)]) /asquared / (nlatentpop*2+1) + diag_matrix(merrorstates[o,2]);
          K[,o] = mdivide_right(ukfstates[,3:cols(ukfstates)] * ukfmeasures[o,3:cols(ukfmeasures)]' /asquared / (nlatentpop*2+1), ypredcov[o,o]); 
        }
        etacov +=  - quad_form(ypredcov[o,o],  K[,o]');
      } //end ukf measurement


      err[o] = Y[rowi,o] - ypred[o]; // prediction error

      if(intoverstates==1) eta +=  (K[,o] * err[o]);
  
      if(nbinary_y[rowi] > 0) kout[rowi,o1] =  Y[rowi,o1] .* (ypred[o1]) + (1-Y[rowi,o1]) .* (1-ypred[o1]); //intoverstates==0 && 
  
        if(verbose > 1) {
          print("rowi ",rowi, "  si ", si, "  eta ",eta,"  etacov ",etacov,
            "  eta ",eta,"  etacov ",etacov,"  ypred ",ypred,"  ypredcov ",ypredcov, "  K ",K,
            "  sDRIFT ", sDRIFT, " sDIFFUSION ", sDIFFUSION, " sCINT ", sCINT, "  sMANIFESTVAR ", diagonal(sMANIFESTVAR), "  sMANIFESTMEANS ", sMANIFESTMEANS, 
            "  sT0VAR", sT0VAR,  " sT0MEANS ", sT0MEANS,
            "  rawpopsd ", rawpopsd,  "  rawpopsdbase ", rawpopsdbase, "  rawpopmeans ", rawpopmeans );
          if(lineardynamics==1) print("discreteDRIFT ",discreteDRIFT,"  discreteCINT ", discreteCINT, "  discreteDIFFUSION ", discreteDIFFUSION)
        }
        if(verbose > 2) print("ukfstates ", ukfstates, "  ukfmeasures ", ukfmeasures);
  
        if(size(o0) > 0){
          int tmpindex[ncont_y[rowi]] = o0;
          for(oi in 1:ncont_y[rowi]) tmpindex[oi] +=  nmanifest;
           if(intoverstates==1) ypredcov_sqrt[o0,o0]=cholesky_decompose(makesym(ypredcov[o0,o0]));
           kout[rowi,o0] = mdivide_left_tri_low(ypredcov_sqrt[o0,o0], err[o0]); //transform pred errors to standard normal dist and collect
           kout[rowi,tmpindex] = log(diagonal(ypredcov_sqrt[o0,o0])); //account for transformation of scale in loglik
        }
      
    }//end nobs > 0 section
  if(savescores==1) kout[rowi,(nmanifest*2+nlatent+1):(nmanifest*2++nlatent+nlatent)] = eta;
}//end rowi

  if(sum(nbinary_y) > 0) {
    vector[sum(nbinary_y)] binaryll;
    counter = 1;
    for(ri in 1:ndatapoints){
      int o1[nbinary_y[ri]] = whichbinary_y[ri,1:nbinary_y[ri]]; //which indicators are observed and binary
      binaryll[counter:(counter + nbinary_y[ri]-1)] = kout[ri,o1];
      counter+= nbinary_y[ri];
    }
    ll+= sum(log(binaryll));
  }

  if(( sum(ncont_y) > 0)) {
    vector[sum(ncont_y)] errtrans[2];
    counter = 1;
    for(ri in 1:ndatapoints){
      int o0[ncont_y[ri]] = whichcont_y[ri,1:ncont_y[ri]]; //which indicators are observed and continuous
      errtrans[1,counter:(counter + ncont_y[ri]-1)] = kout[ri, o0];
      for(oi in 1:ncont_y[ri]) o0[oi] +=  nmanifest; //modify o0 index
      errtrans[2,counter:(counter + ncont_y[ri]-1)] = kout[ri, o0];
      counter+= ncont_y[ri];
    }
    ll += normal_lpdf(errtrans[1]|0,1) - sum(errtrans[2]);
    }

}

}
      
model{

  if(nopriors==0){
    target += normal_lpdf(rawpopmeans|0,1);
  
    if(ntipred > 0){ 
     tipredeffectparams ~ normal(0,tipredeffectscale);
     tipredsimputed ~ normal(0,tipredsimputedscale);
    }
    
    if(nindvarying > 0){
      if(nindvarying >1) sqrtpcov ~ normal(0,1);
      if(intoverpop==0) baseindparams ~ normal(0,1);
      rawpopsdbase ~ normal(0,1);
    }

  } //end pop priors section
  
  if(intoverstates==0) etaupdbasestates ~ normal(0,1);
  
  target += ll;
  
  if(verbose > 0) print("lp = ", target());
  
}
generated quantities{
  vector[nparams] popmeans;
  vector[nparams] popsd;
  matrix[nindvarying,nindvarying] rawpopcov;
  matrix[nindvarying,nindvarying] rawpopcorr;
  matrix[nparams,ntipred] linearTIPREDEFFECT;
  vector[nmanifest] Ygen[gendata ? ndatapoints : 0];

  matrix[ T0MEANSsetup_rowcount ? max(T0MEANSsetup[,1]) : 0, T0MEANSsetup_rowcount ? max(T0MEANSsetup[,2]) : 0 ] pop_T0MEANS;
matrix[ LAMBDAsetup_rowcount ? max(LAMBDAsetup[,1]) : 0, LAMBDAsetup_rowcount ? max(LAMBDAsetup[,2]) : 0 ] pop_LAMBDA;
matrix[ DRIFTsetup_rowcount ? max(DRIFTsetup[,1]) : 0, DRIFTsetup_rowcount ? max(DRIFTsetup[,2]) : 0 ] pop_DRIFT;
matrix[ DIFFUSIONsetup_rowcount ? max(DIFFUSIONsetup[,1]) : 0, DIFFUSIONsetup_rowcount ? max(DIFFUSIONsetup[,2]) : 0 ] pop_DIFFUSION;
matrix[ MANIFESTVARsetup_rowcount ? max(MANIFESTVARsetup[,1]) : 0, MANIFESTVARsetup_rowcount ? max(MANIFESTVARsetup[,2]) : 0 ] pop_MANIFESTVAR;
matrix[ MANIFESTMEANSsetup_rowcount ? max(MANIFESTMEANSsetup[,1]) : 0, MANIFESTMEANSsetup_rowcount ? max(MANIFESTMEANSsetup[,2]) : 0 ] pop_MANIFESTMEANS;
matrix[ CINTsetup_rowcount ? max(CINTsetup[,1]) : 0, CINTsetup_rowcount ? max(CINTsetup[,2]) : 0 ] pop_CINT;
matrix[ T0VARsetup_rowcount ? max(T0VARsetup[,1]) : 0, T0VARsetup_rowcount ? max(T0VARsetup[,2]) : 0 ] pop_T0VAR;
matrix[ TDPREDEFFECTsetup_rowcount ? max(TDPREDEFFECTsetup[,1]) : 0, TDPREDEFFECTsetup_rowcount ? max(TDPREDEFFECTsetup[,2]) : 0 ] pop_TDPREDEFFECT;
matrix[ PARSsetup_rowcount ? max(PARSsetup[,1]) : 0, PARSsetup_rowcount ? max(PARSsetup[,2]) : 0 ] pop_PARS;

  matrix[nlatent,nlatent] pop_asymDIFFUSION; //stationary latent process variance
  vector[nt0meansstationary ? nlatent : 0] pop_asymCINT; // latent process asymptotic level
  

  matrix[ T0MEANSsetup_rowcount ? max(T0MEANSsetup[,1]) : 0, T0MEANSsetup_rowcount ? max(T0MEANSsetup[,2]) : 0 ] T0MEANS[T0MEANSsubindex[nsubjects]];
matrix[ LAMBDAsetup_rowcount ? max(LAMBDAsetup[,1]) : 0, LAMBDAsetup_rowcount ? max(LAMBDAsetup[,2]) : 0 ] LAMBDA[LAMBDAsubindex[nsubjects]];
matrix[ DRIFTsetup_rowcount ? max(DRIFTsetup[,1]) : 0, DRIFTsetup_rowcount ? max(DRIFTsetup[,2]) : 0 ] DRIFT[DRIFTsubindex[nsubjects]];
matrix[ DIFFUSIONsetup_rowcount ? max(DIFFUSIONsetup[,1]) : 0, DIFFUSIONsetup_rowcount ? max(DIFFUSIONsetup[,2]) : 0 ] DIFFUSION[DIFFUSIONsubindex[nsubjects]];
matrix[ MANIFESTVARsetup_rowcount ? max(MANIFESTVARsetup[,1]) : 0, MANIFESTVARsetup_rowcount ? max(MANIFESTVARsetup[,2]) : 0 ] MANIFESTVAR[MANIFESTVARsubindex[nsubjects]];
matrix[ MANIFESTMEANSsetup_rowcount ? max(MANIFESTMEANSsetup[,1]) : 0, MANIFESTMEANSsetup_rowcount ? max(MANIFESTMEANSsetup[,2]) : 0 ] MANIFESTMEANS[MANIFESTMEANSsubindex[nsubjects]];
matrix[ CINTsetup_rowcount ? max(CINTsetup[,1]) : 0, CINTsetup_rowcount ? max(CINTsetup[,2]) : 0 ] CINT[CINTsubindex[nsubjects]];
matrix[ T0VARsetup_rowcount ? max(T0VARsetup[,1]) : 0, T0VARsetup_rowcount ? max(T0VARsetup[,2]) : 0 ] T0VAR[T0VARsubindex[nsubjects]];
matrix[ TDPREDEFFECTsetup_rowcount ? max(TDPREDEFFECTsetup[,1]) : 0, TDPREDEFFECTsetup_rowcount ? max(TDPREDEFFECTsetup[,2]) : 0 ] TDPREDEFFECT[TDPREDEFFECTsubindex[nsubjects]];
matrix[ PARSsetup_rowcount ? max(PARSsetup[,1]) : 0, PARSsetup_rowcount ? max(PARSsetup[,2]) : 0 ] PARS[PARSsubindex[nsubjects]];

  matrix[nlatent,nlatent] asymDIFFUSION[asymDIFFUSIONsubindex[nsubjects]]; //stationary latent process variance
  vector[nt0meansstationary ? nlatent : 0] asymCINT[asymCINTsubindex[nsubjects]]; // latent process asymptotic level
  

  {
  matrix[ T0MEANSsetup_rowcount ? max(T0MEANSsetup[,1]) : 0, T0MEANSsetup_rowcount ? max(T0MEANSsetup[,2]) : 0 ] sT0MEANS;
matrix[ LAMBDAsetup_rowcount ? max(LAMBDAsetup[,1]) : 0, LAMBDAsetup_rowcount ? max(LAMBDAsetup[,2]) : 0 ] sLAMBDA;
matrix[ DRIFTsetup_rowcount ? max(DRIFTsetup[,1]) : 0, DRIFTsetup_rowcount ? max(DRIFTsetup[,2]) : 0 ] sDRIFT;
matrix[ DIFFUSIONsetup_rowcount ? max(DIFFUSIONsetup[,1]) : 0, DIFFUSIONsetup_rowcount ? max(DIFFUSIONsetup[,2]) : 0 ] sDIFFUSION;
matrix[ MANIFESTVARsetup_rowcount ? max(MANIFESTVARsetup[,1]) : 0, MANIFESTVARsetup_rowcount ? max(MANIFESTVARsetup[,2]) : 0 ] sMANIFESTVAR;
matrix[ MANIFESTMEANSsetup_rowcount ? max(MANIFESTMEANSsetup[,1]) : 0, MANIFESTMEANSsetup_rowcount ? max(MANIFESTMEANSsetup[,2]) : 0 ] sMANIFESTMEANS;
matrix[ CINTsetup_rowcount ? max(CINTsetup[,1]) : 0, CINTsetup_rowcount ? max(CINTsetup[,2]) : 0 ] sCINT;
matrix[ T0VARsetup_rowcount ? max(T0VARsetup[,1]) : 0, T0VARsetup_rowcount ? max(T0VARsetup[,2]) : 0 ] sT0VAR;
matrix[ TDPREDEFFECTsetup_rowcount ? max(TDPREDEFFECTsetup[,1]) : 0, TDPREDEFFECTsetup_rowcount ? max(TDPREDEFFECTsetup[,2]) : 0 ] sTDPREDEFFECT;
matrix[ PARSsetup_rowcount ? max(PARSsetup[,1]) : 0, PARSsetup_rowcount ? max(PARSsetup[,2]) : 0 ] sPARS;

  matrix[nlatent,nlatent] sasymDIFFUSION; //stationary latent process variance
  vector[nt0meansstationary ? nlatent : 0] sasymCINT; // latent process asymptotic level
  

  for(rowi in 1:ndatapoints){
    if(T0check[rowi]==1){
    int si = subject[rowi];
    {
  vector[nparams] rawindparams;
  vector[nparams] tipredaddition;
  vector[nparams] indvaraddition;
  
  if(si < 2 || (si > 1 && (nindvarying >0 || ntipred > 0))){ //si of 0 used
    tipredaddition = rep_vector(0,nparams);
    indvaraddition = rep_vector(0,nparams);

    if(si > 0 && nindvarying > 0 && intoverpop==0) indvaraddition[indvaryingindex] = rawpopcovsqrt * baseindparams[(1+(si-1)*nindvarying):(si*nindvarying)];
  
    if(si > 0 &&  ntipred > 0) tipredaddition = TIPREDEFFECT * tipreds[si]';
  
    rawindparams = rawpopmeans + tipredaddition + indvaraddition;
  }

  if(si <= T0MEANSsubindex[nsubjects]){
    for(ri in 1:size(T0MEANSsetup)){
      if(si==1 || T0MEANSsetup[ri,5] > 0 || T0MEANSsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sT0MEANS[T0MEANSsetup[ ri,1], T0MEANSsetup[ri,2]] = T0MEANSsetup[ri,3] ? tform(rawindparams[ T0MEANSsetup[ri,3] ], T0MEANSsetup[ri,4], T0MEANSvalues[ri,2], T0MEANSvalues[ri,3], T0MEANSvalues[ri,4] ) : T0MEANSvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= LAMBDAsubindex[nsubjects]){
    for(ri in 1:size(LAMBDAsetup)){
      if(si==1 || LAMBDAsetup[ri,5] > 0 || LAMBDAsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sLAMBDA[LAMBDAsetup[ ri,1], LAMBDAsetup[ri,2]] = LAMBDAsetup[ri,3] ? tform(rawindparams[ LAMBDAsetup[ri,3] ], LAMBDAsetup[ri,4], LAMBDAvalues[ri,2], LAMBDAvalues[ri,3], LAMBDAvalues[ri,4] ) : LAMBDAvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= DRIFTsubindex[nsubjects]){
    for(ri in 1:size(DRIFTsetup)){
      if(si==1 || DRIFTsetup[ri,5] > 0 || DRIFTsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sDRIFT[DRIFTsetup[ ri,1], DRIFTsetup[ri,2]] = DRIFTsetup[ri,3] ? tform(rawindparams[ DRIFTsetup[ri,3] ], DRIFTsetup[ri,4], DRIFTvalues[ri,2], DRIFTvalues[ri,3], DRIFTvalues[ri,4] ) : DRIFTvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= DIFFUSIONsubindex[nsubjects]){
    for(ri in 1:size(DIFFUSIONsetup)){
      if(si==1 || DIFFUSIONsetup[ri,5] > 0 || DIFFUSIONsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sDIFFUSION[DIFFUSIONsetup[ ri,1], DIFFUSIONsetup[ri,2]] = DIFFUSIONsetup[ri,3] ? tform(rawindparams[ DIFFUSIONsetup[ri,3] ], DIFFUSIONsetup[ri,4], DIFFUSIONvalues[ri,2], DIFFUSIONvalues[ri,3], DIFFUSIONvalues[ri,4] ) : DIFFUSIONvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= MANIFESTVARsubindex[nsubjects]){
    for(ri in 1:size(MANIFESTVARsetup)){
      if(si==1 || MANIFESTVARsetup[ri,5] > 0 || MANIFESTVARsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sMANIFESTVAR[MANIFESTVARsetup[ ri,1], MANIFESTVARsetup[ri,2]] = MANIFESTVARsetup[ri,3] ? tform(rawindparams[ MANIFESTVARsetup[ri,3] ], MANIFESTVARsetup[ri,4], MANIFESTVARvalues[ri,2], MANIFESTVARvalues[ri,3], MANIFESTVARvalues[ri,4] ) : MANIFESTVARvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= MANIFESTMEANSsubindex[nsubjects]){
    for(ri in 1:size(MANIFESTMEANSsetup)){
      if(si==1 || MANIFESTMEANSsetup[ri,5] > 0 || MANIFESTMEANSsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sMANIFESTMEANS[MANIFESTMEANSsetup[ ri,1], MANIFESTMEANSsetup[ri,2]] = MANIFESTMEANSsetup[ri,3] ? tform(rawindparams[ MANIFESTMEANSsetup[ri,3] ], MANIFESTMEANSsetup[ri,4], MANIFESTMEANSvalues[ri,2], MANIFESTMEANSvalues[ri,3], MANIFESTMEANSvalues[ri,4] ) : MANIFESTMEANSvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= CINTsubindex[nsubjects]){
    for(ri in 1:size(CINTsetup)){
      if(si==1 || CINTsetup[ri,5] > 0 || CINTsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sCINT[CINTsetup[ ri,1], CINTsetup[ri,2]] = CINTsetup[ri,3] ? tform(rawindparams[ CINTsetup[ri,3] ], CINTsetup[ri,4], CINTvalues[ri,2], CINTvalues[ri,3], CINTvalues[ri,4] ) : CINTvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= T0VARsubindex[nsubjects]){
    for(ri in 1:size(T0VARsetup)){
      if(si==1 || T0VARsetup[ri,5] > 0 || T0VARsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sT0VAR[T0VARsetup[ ri,1], T0VARsetup[ri,2]] = T0VARsetup[ri,3] ? tform(rawindparams[ T0VARsetup[ri,3] ], T0VARsetup[ri,4], T0VARvalues[ri,2], T0VARvalues[ri,3], T0VARvalues[ri,4] ) : T0VARvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= TDPREDEFFECTsubindex[nsubjects]){
    for(ri in 1:size(TDPREDEFFECTsetup)){
      if(si==1 || TDPREDEFFECTsetup[ri,5] > 0 || TDPREDEFFECTsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sTDPREDEFFECT[TDPREDEFFECTsetup[ ri,1], TDPREDEFFECTsetup[ri,2]] = TDPREDEFFECTsetup[ri,3] ? tform(rawindparams[ TDPREDEFFECTsetup[ri,3] ], TDPREDEFFECTsetup[ri,4], TDPREDEFFECTvalues[ri,2], TDPREDEFFECTvalues[ri,3], TDPREDEFFECTvalues[ri,4] ) : TDPREDEFFECTvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= PARSsubindex[nsubjects]){
    for(ri in 1:size(PARSsetup)){
      if(si==1 || PARSsetup[ri,5] > 0 || PARSsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sPARS[PARSsetup[ ri,1], PARSsetup[ri,2]] = PARSsetup[ri,3] ? tform(rawindparams[ PARSsetup[ri,3] ], PARSsetup[ri,4], PARSvalues[ri,2], PARSvalues[ri,3], PARSvalues[ri,4] ) : PARSvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  // perform any whole matrix transformations 
    
  if(si <= DIFFUSIONsubindex[nsubjects] && ukf==0) sDIFFUSION = sdcovsqrt2cov(sDIFFUSION);

    if(si <= asymDIFFUSIONsubindex[nsubjects]) {
      if(ndiffusion < nlatent) sasymDIFFUSION = to_matrix(rep_vector(0,nlatent * nlatent),nlatent,nlatent);

      if(continuoustime==1 && ukf==0) sasymDIFFUSION[ derrind, derrind] = to_matrix( 
      -( kron_prod( sDRIFT[ derrind, derrind ], IIlatent[ derrind, derrind ]) + 
         kron_prod(IIlatent[ derrind, derrind ], sDRIFT[ derrind, derrind ]) ) \ 
      to_vector( sDIFFUSION[ derrind, derrind ] + IIlatent[ derrind, derrind ] * 1e-5), ndiffusion,ndiffusion);

      if(continuoustime==0) sasymDIFFUSION = to_matrix( (IIlatent2 - 
        kron_prod(sDRIFT, sDRIFT)) *  to_vector(sDIFFUSION) , ndiffusion, ndiffusion);
    } //end asymdiffusion loops
          
    if(nt0meansstationary > 0){
      if(si <= asymCINTsubindex[nsubjects]){
        if(continuoustime==1) sasymCINT =  -sDRIFT \ sCINT[ ,1 ];
        if(continuoustime==0) sasymCINT =  (IIlatent - sDRIFT) \ sCINT[,1 ];
      }
    }

          
    if(binomial==0){
      if(si <= MANIFESTVARsubindex[nsubjects]) {
         for(ri in 1:nmanifest) sMANIFESTVAR[ri,ri] = square(sMANIFESTVAR[ri,ri]);
      }
    }
          
          
    if(si <= T0VARsubindex[nsubjects]) {
      if(ukf==0) sT0VAR = sdcovsqrt2cov(sT0VAR);
      if(nt0varstationary > 0) for(ri in 1:nt0varstationary){
        sT0VAR[t0varstationary[ri,1],t0varstationary[ri,2] ] = 
          sasymDIFFUSION[t0varstationary[ri,1],t0varstationary[ri,2] ];
        sT0VAR[t0varstationary[ri,2],t0varstationary[ri,1] ] = 
          sasymDIFFUSION[t0varstationary[ri,2],t0varstationary[ri,1] ];
      }
    }
    
    if(nt0meansstationary > 0){
      if(si <= T0MEANSsubindex[nsubjects]) {
        for(ri in 1:nt0meansstationary){
          sT0MEANS[t0meansstationary[ri,1] , 1] = 
            sasymCINT[t0meansstationary[ri,1] ];
        }
      }
    }
  T0MEANS[T0MEANSsubindex[si]] = sT0MEANS; 
LAMBDA[LAMBDAsubindex[si]] = sLAMBDA; 
DRIFT[DRIFTsubindex[si]] = sDRIFT; 
DIFFUSION[DIFFUSIONsubindex[si]] = sDIFFUSION; 
MANIFESTVAR[MANIFESTVARsubindex[si]] = sMANIFESTVAR; 
MANIFESTMEANS[MANIFESTMEANSsubindex[si]] = sMANIFESTMEANS; 
CINT[CINTsubindex[si]] = sCINT; 
T0VAR[T0VARsubindex[si]] = sT0VAR; 
TDPREDEFFECT[TDPREDEFFECTsubindex[si]] = sTDPREDEFFECT; 
PARS[PARSsubindex[si]] = sPARS; 
asymDIFFUSION[asymDIFFUSIONsubindex[si]] = sasymDIFFUSION; 
asymCINT[asymCINTsubindex[si]] = sasymCINT; 
pop_T0MEANS = sT0MEANS; 
pop_LAMBDA = sLAMBDA; 
pop_DRIFT = sDRIFT; 
pop_DIFFUSION = sDIFFUSION; 
pop_MANIFESTVAR = sMANIFESTVAR; 
pop_MANIFESTMEANS = sMANIFESTMEANS; 
pop_CINT = sCINT; 
pop_T0VAR = sT0VAR; 
pop_TDPREDEFFECT = sTDPREDEFFECT; 
pop_PARS = sPARS; 
pop_asymDIFFUSION = sasymDIFFUSION; 
pop_asymCINT = sasymCINT; 

 }
  
    }
  }
  }


  if(gendata > 0){
  vector[nmanifest] Ygenbase[ndatapoints];
  Ygen = rep_array(rep_vector(99999,nmanifest),ndatapoints);
  for(mi in 1:nmanifest){
    if(manifesttype[mi]==0 || manifesttype[mi]==2) {
      Ygenbase[1:ndatapoints,mi] = normal_rng(rep_vector(0,gendata*ndatapoints),rep_vector(1,gendata*ndatapoints));
    }
    if(manifesttype[mi]==1){
      Ygenbase[1:ndatapoints,mi] =  uniform_rng(rep_vector(0,gendata*ndatapoints),rep_vector(1,gendata*ndatapoints));
    }
  }
{

  int si;
  int counter = 0;
  vector[nlatentpop] eta; //latent states
  matrix[nlatentpop, nlatentpop] etacov; //covariance of latent states

  //measurement 
  vector[nmanifest] err;
  vector[nmanifest] ypred;
  vector[ukf ? nmanifest : 0] ystate;
  matrix[nmanifest, nmanifest] ypredcov;
  matrix[nlatentpop, nmanifest] K; // kalman gain
  matrix[nmanifest, nmanifest] ypredcov_sqrt; 

  vector[nmanifest+nmanifest+ (savescores ? nmanifest*2+nlatent*2 : 0)] kout[ndatapoints];

  //ukf
  matrix[ukf ? nlatentpop :0,ukf ? nlatentpop :0] sigpoints;

  //linear continuous time calcs
  matrix[nlatent+1,nlatent+1] discreteDRIFT;
  vector[lineardynamics + ( 1-continuoustime)  ? nlatent : 0] discreteCINT;
  matrix[nlatent,nlatent] discreteDIFFUSION;

  //dynamic system matrices
  matrix[ T0MEANSsetup_rowcount ? max(T0MEANSsetup[,1]) : 0, T0MEANSsetup_rowcount ? max(T0MEANSsetup[,2]) : 0 ] sT0MEANS;
matrix[ LAMBDAsetup_rowcount ? max(LAMBDAsetup[,1]) : 0, LAMBDAsetup_rowcount ? max(LAMBDAsetup[,2]) : 0 ] sLAMBDA;
matrix[ DRIFTsetup_rowcount ? max(DRIFTsetup[,1]) : 0, DRIFTsetup_rowcount ? max(DRIFTsetup[,2]) : 0 ] sDRIFT;
matrix[ DIFFUSIONsetup_rowcount ? max(DIFFUSIONsetup[,1]) : 0, DIFFUSIONsetup_rowcount ? max(DIFFUSIONsetup[,2]) : 0 ] sDIFFUSION;
matrix[ MANIFESTVARsetup_rowcount ? max(MANIFESTVARsetup[,1]) : 0, MANIFESTVARsetup_rowcount ? max(MANIFESTVARsetup[,2]) : 0 ] sMANIFESTVAR;
matrix[ MANIFESTMEANSsetup_rowcount ? max(MANIFESTMEANSsetup[,1]) : 0, MANIFESTMEANSsetup_rowcount ? max(MANIFESTMEANSsetup[,2]) : 0 ] sMANIFESTMEANS;
matrix[ CINTsetup_rowcount ? max(CINTsetup[,1]) : 0, CINTsetup_rowcount ? max(CINTsetup[,2]) : 0 ] sCINT;
matrix[ T0VARsetup_rowcount ? max(T0VARsetup[,1]) : 0, T0VARsetup_rowcount ? max(T0VARsetup[,2]) : 0 ] sT0VAR;
matrix[ TDPREDEFFECTsetup_rowcount ? max(TDPREDEFFECTsetup[,1]) : 0, TDPREDEFFECTsetup_rowcount ? max(TDPREDEFFECTsetup[,2]) : 0 ] sTDPREDEFFECT;
matrix[ PARSsetup_rowcount ? max(PARSsetup[,1]) : 0, PARSsetup_rowcount ? max(PARSsetup[,2]) : 0 ] sPARS;

  matrix[nlatent,nlatent] sasymDIFFUSION; //stationary latent process variance
  vector[nt0meansstationary ? nlatent : 0] sasymCINT; // latent process asymptotic level
  

  if(lineardynamics) discreteDIFFUSION = rep_matrix(0,nlatent,nlatent); //in case some elements remain zero due to derrind

  for(rowi in 1:ndatapoints){


    matrix[ukf ? nlatentpop : 0, ukffull ? 2*nlatentpop +2 : nlatentpop + 2 ] ukfstates; //sampled states relevant for dynamics
    matrix[ukf ? nmanifest : 0 , ukffull ? 2*nlatentpop +2 : nlatentpop + 2] ukfmeasures; // expected measures based on sampled states

    si=subject[rowi];
    
    if(T0check[rowi] == 1) { // calculate initial matrices if this is first row for si

    {
  vector[nparams] rawindparams;
  vector[nparams] tipredaddition;
  vector[nparams] indvaraddition;
  
  if(si < 2 || (si > 1 && (nindvarying >0 || ntipred > 0))){ //si of 0 used
    tipredaddition = rep_vector(0,nparams);
    indvaraddition = rep_vector(0,nparams);

    if(si > 0 && nindvarying > 0 && intoverpop==0) indvaraddition[indvaryingindex] = rawpopcovsqrt * baseindparams[(1+(si-1)*nindvarying):(si*nindvarying)];
  
    if(si > 0 &&  ntipred > 0) tipredaddition = TIPREDEFFECT * tipreds[si]';
  
    rawindparams = rawpopmeans + tipredaddition + indvaraddition;
  }

  if(si <= T0MEANSsubindex[nsubjects]){
    for(ri in 1:size(T0MEANSsetup)){
      if(si==1 || T0MEANSsetup[ri,5] > 0 || T0MEANSsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sT0MEANS[T0MEANSsetup[ ri,1], T0MEANSsetup[ri,2]] = T0MEANSsetup[ri,3] ? tform(rawindparams[ T0MEANSsetup[ri,3] ], T0MEANSsetup[ri,4], T0MEANSvalues[ri,2], T0MEANSvalues[ri,3], T0MEANSvalues[ri,4] ) : T0MEANSvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= LAMBDAsubindex[nsubjects]){
    for(ri in 1:size(LAMBDAsetup)){
      if(si==1 || LAMBDAsetup[ri,5] > 0 || LAMBDAsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sLAMBDA[LAMBDAsetup[ ri,1], LAMBDAsetup[ri,2]] = LAMBDAsetup[ri,3] ? tform(rawindparams[ LAMBDAsetup[ri,3] ], LAMBDAsetup[ri,4], LAMBDAvalues[ri,2], LAMBDAvalues[ri,3], LAMBDAvalues[ri,4] ) : LAMBDAvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= DRIFTsubindex[nsubjects]){
    for(ri in 1:size(DRIFTsetup)){
      if(si==1 || DRIFTsetup[ri,5] > 0 || DRIFTsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sDRIFT[DRIFTsetup[ ri,1], DRIFTsetup[ri,2]] = DRIFTsetup[ri,3] ? tform(rawindparams[ DRIFTsetup[ri,3] ], DRIFTsetup[ri,4], DRIFTvalues[ri,2], DRIFTvalues[ri,3], DRIFTvalues[ri,4] ) : DRIFTvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= DIFFUSIONsubindex[nsubjects]){
    for(ri in 1:size(DIFFUSIONsetup)){
      if(si==1 || DIFFUSIONsetup[ri,5] > 0 || DIFFUSIONsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sDIFFUSION[DIFFUSIONsetup[ ri,1], DIFFUSIONsetup[ri,2]] = DIFFUSIONsetup[ri,3] ? tform(rawindparams[ DIFFUSIONsetup[ri,3] ], DIFFUSIONsetup[ri,4], DIFFUSIONvalues[ri,2], DIFFUSIONvalues[ri,3], DIFFUSIONvalues[ri,4] ) : DIFFUSIONvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= MANIFESTVARsubindex[nsubjects]){
    for(ri in 1:size(MANIFESTVARsetup)){
      if(si==1 || MANIFESTVARsetup[ri,5] > 0 || MANIFESTVARsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sMANIFESTVAR[MANIFESTVARsetup[ ri,1], MANIFESTVARsetup[ri,2]] = MANIFESTVARsetup[ri,3] ? tform(rawindparams[ MANIFESTVARsetup[ri,3] ], MANIFESTVARsetup[ri,4], MANIFESTVARvalues[ri,2], MANIFESTVARvalues[ri,3], MANIFESTVARvalues[ri,4] ) : MANIFESTVARvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= MANIFESTMEANSsubindex[nsubjects]){
    for(ri in 1:size(MANIFESTMEANSsetup)){
      if(si==1 || MANIFESTMEANSsetup[ri,5] > 0 || MANIFESTMEANSsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sMANIFESTMEANS[MANIFESTMEANSsetup[ ri,1], MANIFESTMEANSsetup[ri,2]] = MANIFESTMEANSsetup[ri,3] ? tform(rawindparams[ MANIFESTMEANSsetup[ri,3] ], MANIFESTMEANSsetup[ri,4], MANIFESTMEANSvalues[ri,2], MANIFESTMEANSvalues[ri,3], MANIFESTMEANSvalues[ri,4] ) : MANIFESTMEANSvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= CINTsubindex[nsubjects]){
    for(ri in 1:size(CINTsetup)){
      if(si==1 || CINTsetup[ri,5] > 0 || CINTsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sCINT[CINTsetup[ ri,1], CINTsetup[ri,2]] = CINTsetup[ri,3] ? tform(rawindparams[ CINTsetup[ri,3] ], CINTsetup[ri,4], CINTvalues[ri,2], CINTvalues[ri,3], CINTvalues[ri,4] ) : CINTvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= T0VARsubindex[nsubjects]){
    for(ri in 1:size(T0VARsetup)){
      if(si==1 || T0VARsetup[ri,5] > 0 || T0VARsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sT0VAR[T0VARsetup[ ri,1], T0VARsetup[ri,2]] = T0VARsetup[ri,3] ? tform(rawindparams[ T0VARsetup[ri,3] ], T0VARsetup[ri,4], T0VARvalues[ri,2], T0VARvalues[ri,3], T0VARvalues[ri,4] ) : T0VARvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= TDPREDEFFECTsubindex[nsubjects]){
    for(ri in 1:size(TDPREDEFFECTsetup)){
      if(si==1 || TDPREDEFFECTsetup[ri,5] > 0 || TDPREDEFFECTsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sTDPREDEFFECT[TDPREDEFFECTsetup[ ri,1], TDPREDEFFECTsetup[ri,2]] = TDPREDEFFECTsetup[ri,3] ? tform(rawindparams[ TDPREDEFFECTsetup[ri,3] ], TDPREDEFFECTsetup[ri,4], TDPREDEFFECTvalues[ri,2], TDPREDEFFECTvalues[ri,3], TDPREDEFFECTvalues[ri,4] ) : TDPREDEFFECTvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  if(si <= PARSsubindex[nsubjects]){
    for(ri in 1:size(PARSsetup)){
      if(si==1 || PARSsetup[ri,5] > 0 || PARSsetup[ri,6] > 0){ // if first subject, indvarying, and or tipred effects
          sPARS[PARSsetup[ ri,1], PARSsetup[ri,2]] = PARSsetup[ri,3] ? tform(rawindparams[ PARSsetup[ri,3] ], PARSsetup[ri,4], PARSvalues[ri,2], PARSvalues[ri,3], PARSvalues[ri,4] ) : PARSvalues[ri,1]; //either transformed, scaled and offset free par, or fixed value
      }
    }
  }
      

  // perform any whole matrix transformations 
    
  if(si <= DIFFUSIONsubindex[nsubjects] && ukf==0) sDIFFUSION = sdcovsqrt2cov(sDIFFUSION);

    if(si <= asymDIFFUSIONsubindex[nsubjects]) {
      if(ndiffusion < nlatent) sasymDIFFUSION = to_matrix(rep_vector(0,nlatent * nlatent),nlatent,nlatent);

      if(continuoustime==1 && ukf==0) sasymDIFFUSION[ derrind, derrind] = to_matrix( 
      -( kron_prod( sDRIFT[ derrind, derrind ], IIlatent[ derrind, derrind ]) + 
         kron_prod(IIlatent[ derrind, derrind ], sDRIFT[ derrind, derrind ]) ) \ 
      to_vector( sDIFFUSION[ derrind, derrind ] + IIlatent[ derrind, derrind ] * 1e-5), ndiffusion,ndiffusion);

      if(continuoustime==0) sasymDIFFUSION = to_matrix( (IIlatent2 - 
        kron_prod(sDRIFT, sDRIFT)) *  to_vector(sDIFFUSION) , ndiffusion, ndiffusion);
    } //end asymdiffusion loops
          
    if(nt0meansstationary > 0){
      if(si <= asymCINTsubindex[nsubjects]){
        if(continuoustime==1) sasymCINT =  -sDRIFT \ sCINT[ ,1 ];
        if(continuoustime==0) sasymCINT =  (IIlatent - sDRIFT) \ sCINT[,1 ];
      }
    }

          
    if(binomial==0){
      if(si <= MANIFESTVARsubindex[nsubjects]) {
         for(ri in 1:nmanifest) sMANIFESTVAR[ri,ri] = square(sMANIFESTVAR[ri,ri]);
      }
    }
          
          
    if(si <= T0VARsubindex[nsubjects]) {
      if(ukf==0) sT0VAR = sdcovsqrt2cov(sT0VAR);
      if(nt0varstationary > 0) for(ri in 1:nt0varstationary){
        sT0VAR[t0varstationary[ri,1],t0varstationary[ri,2] ] = 
          sasymDIFFUSION[t0varstationary[ri,1],t0varstationary[ri,2] ];
        sT0VAR[t0varstationary[ri,2],t0varstationary[ri,1] ] = 
          sasymDIFFUSION[t0varstationary[ri,2],t0varstationary[ri,1] ];
      }
    }
    
    if(nt0meansstationary > 0){
      if(si <= T0MEANSsubindex[nsubjects]) {
        for(ri in 1:nt0meansstationary){
          sT0MEANS[t0meansstationary[ri,1] , 1] = 
            sasymCINT[t0meansstationary[ri,1] ];
        }
      }
    }
  
 }
  

      if(ukf==1){
        eta = rep_vector(0,nlatentpop); // because some values stay zero
        sigpoints = rep_matrix(0, nlatentpop,nlatentpop);
      
        if(intoverpop==1) {
          if(ntipred ==0) eta[ (nlatent+1):(nlatentpop)] = rawpopmeans[indvaryingindex];
          if(ntipred >0) eta[ (nlatent+1):(nlatentpop)] = rawpopmeans[indvaryingindex] + TIPREDEFFECT[indvaryingindex] * tipreds[si]';
        }
      }


      if(ukf==0){
      eta = sT0MEANS[,1]; //prior for initial latent state
      if(ntdpred > 0) eta += sTDPREDEFFECT * tdpreds[rowi];
      etacov =  sT0VAR;
      }

    } //end T0 matrices

    if(lineardynamics==1 && ukf==0 && T0check[rowi]==0){ //linear kf time update
    
      if(continuoustime ==1){
        int dtchange = 0;
        if(si==1 && T0check[rowi -1] == 1) {
          dtchange = 1;
        } else if(T0check[rowi-1] == 1 && dT[rowi-2] != dT[rowi]){
          dtchange = 1;
        } else if(T0check[rowi-1] == 0 && dT[rowi-1] != dT[rowi]) dtchange = 1;
        
        if(dtchange==1 || (T0check[rowi-1]==1 && si <= DRIFTsubindex[si] && si <= CINTsubindex[si])){
          discreteDRIFT = expm2(append_row(append_col(sDRIFT,sCINT),rep_matrix(0,1,nlatent+1)) * dT[rowi]);
        }
    
        if(dtchange==1 || (T0check[rowi-1]==1 && (si <= DIFFUSIONsubindex[si]|| si <= DRIFTsubindex[si]))){
          discreteDIFFUSION[derrind, derrind] = sasymDIFFUSION[derrind, derrind] - 
            quad_form( sasymDIFFUSION[derrind, derrind], discreteDRIFT[derrind, derrind]' );
          //discreteDIFFUSION[derrind, derrind] = discreteDIFFUSIONcalc(sDRIFT[derrind, derrind], sDIFFUSION[derrind, derrind], dT[rowi]);
          if(intoverstates==0) discreteDIFFUSION = cholesky_decompose(discreteDIFFUSION);
        }
      }
  
      if(continuoustime==0 && T0check[rowi-1] == 1){
        discreteDRIFT=append_row(append_col(sDRIFT,sCINT),rep_matrix(0,1,nlatent+1));
        discreteDRIFT[nlatent+1,nlatent+1] = 1;
        //discreteCINT=sCINT[,1];
        discreteDIFFUSION=sDIFFUSION;
        if(intoverstates==0) discreteDIFFUSION = cholesky_decompose(discreteDIFFUSION);
      }

      eta = (discreteDRIFT * append_row(eta,1.0))[1:nlatent];
      if(ntdpred > 0) eta += sTDPREDEFFECT * tdpreds[rowi];
      if(intoverstates==1) {
        etacov = quad_form(etacov, discreteDRIFT[1:nlatent,1:nlatent]');
        if(ndiffusion > 0) etacov += discreteDIFFUSION;
      }
    }//end linear time update


    if(ukf==1){ //ukf time update
      vector[nlatentpop] state;
      if(T0check[rowi]==0){
        matrix[nlatentpop,nlatentpop] J;
        vector[nlatent] base;
        J = rep_matrix(0,nlatentpop,nlatentpop); //dont necessarily need to loop over tdpreds here...
        if(continuoustime==1){
          matrix[nlatentpop,nlatentpop] Je;
          matrix[nlatent*2,nlatent*2] dQi;
          for(stepi in 1:integrationsteps[rowi]){
            for(statei in 0:nlatentpop){
              if(statei>0){
                J[statei,statei] = 1e-6;
                state = eta + J[,statei];
              } else {
                state = eta;
              }
              ;
;

    if(intoverpop==1){

    for(ri in 1:size(DRIFTsetup)){ //for each row of matrix setup
      if(DRIFTsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ DRIFTsetup[ ri,5]){
          sDRIFT[DRIFTsetup[ ri,1], DRIFTsetup[ri,2]] = 
            tform(state[nlatent +DRIFTsetup[ri,5] ], DRIFTsetup[ri,4], DRIFTvalues[ri,2], DRIFTvalues[ri,3], DRIFTvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(DIFFUSIONsetup)){ //for each row of matrix setup
      if(DIFFUSIONsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ DIFFUSIONsetup[ ri,5]){
          sDIFFUSION[DIFFUSIONsetup[ ri,1], DIFFUSIONsetup[ri,2]] = 
            tform(state[nlatent +DIFFUSIONsetup[ri,5] ], DIFFUSIONsetup[ri,4], DIFFUSIONvalues[ri,2], DIFFUSIONvalues[ri,3], DIFFUSIONvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(CINTsetup)){ //for each row of matrix setup
      if(CINTsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ CINTsetup[ ri,5]){
          sCINT[CINTsetup[ ri,1], CINTsetup[ri,2]] = 
            tform(state[nlatent +CINTsetup[ri,5] ], CINTsetup[ri,4], CINTvalues[ri,2], CINTvalues[ri,3], CINTvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(PARSsetup)){ //for each row of matrix setup
      if(PARSsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ PARSsetup[ ri,5]){
          sPARS[PARSsetup[ ri,1], PARSsetup[ri,2]] = 
            tform(state[nlatent +PARSsetup[ri,5] ], PARSsetup[ri,4], PARSvalues[ri,2], PARSvalues[ri,3], PARSvalues[ri,4] ); 
        }
      }
    }} //remove diffusion calcs and do elsewhere
              if(statei== 0) {
                base = sDRIFT * state[1:nlatent] + sCINT[,1];
              }
              if(statei > 0) J[1:nlatent,statei] = (( sDRIFT * state[1:nlatent] + sCINT[,1]) - base)/1e-6;
            }
            ;

            Je= expm2(J * dTsmall[rowi]) ;
            discreteDRIFT = expm2(append_row(append_col(sDRIFT,sCINT),rep_vector(0,nlatent+1)') * dTsmall[rowi]);
            sasymDIFFUSION = to_matrix(  -( kron_prod( J[1:nlatent,1:nlatent], IIlatent) +  
              kron_prod(IIlatent, J[1:nlatent,1:nlatent]) ) \ to_vector(tcrossprod(sDIFFUSION)), nlatent,nlatent);
            discreteDIFFUSION =  sasymDIFFUSION - quad_form( sasymDIFFUSION, Je[1:nlatent,1:nlatent]' );
            etacov = quad_form(etacov, Je');
            etacov[1:nlatent,1:nlatent] += discreteDIFFUSION;
            eta[1:nlatent] = (discreteDRIFT * append_row(eta[1:nlatent],1.0))[1:nlatent];
          }
        }

        if(continuoustime==0){ //need covariance in here
            for(statei in 0:nlatentpop){
              if(statei>0){
                J[statei,statei] = 1e-6;
                state = eta + J[,statei];
              } else {
                state = eta;
              }
              ;
;

    if(intoverpop==1){

    for(ri in 1:size(DRIFTsetup)){ //for each row of matrix setup
      if(DRIFTsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ DRIFTsetup[ ri,5]){
          sDRIFT[DRIFTsetup[ ri,1], DRIFTsetup[ri,2]] = 
            tform(state[nlatent +DRIFTsetup[ri,5] ], DRIFTsetup[ri,4], DRIFTvalues[ri,2], DRIFTvalues[ri,3], DRIFTvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(DIFFUSIONsetup)){ //for each row of matrix setup
      if(DIFFUSIONsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ DIFFUSIONsetup[ ri,5]){
          sDIFFUSION[DIFFUSIONsetup[ ri,1], DIFFUSIONsetup[ri,2]] = 
            tform(state[nlatent +DIFFUSIONsetup[ri,5] ], DIFFUSIONsetup[ri,4], DIFFUSIONvalues[ri,2], DIFFUSIONvalues[ri,3], DIFFUSIONvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(CINTsetup)){ //for each row of matrix setup
      if(CINTsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ CINTsetup[ ri,5]){
          sCINT[CINTsetup[ ri,1], CINTsetup[ri,2]] = 
            tform(state[nlatent +CINTsetup[ri,5] ], CINTsetup[ri,4], CINTvalues[ri,2], CINTvalues[ri,3], CINTvalues[ri,4] ); 
        }
      }
    }

    for(ri in 1:size(PARSsetup)){ //for each row of matrix setup
      if(PARSsetup[ ri,5] > 0){ // if individually varying
        if(statei == 0 || statei == nlatent+ PARSsetup[ ri,5]){
          sPARS[PARSsetup[ ri,1], PARSsetup[ri,2]] = 
            tform(state[nlatent +PARSsetup[ri,5] ], PARSsetup[ri,4], PARSvalues[ri,2], PARSvalues[ri,3], PARSvalues[ri,4] ); 
        }
      }
    }} //remove diffusion calcs and do elsewhere
              if(statei== 0) {
                base = sDRIFT * state[1:nlatent] + sCINT[,1];
              }
              if(statei > 0) J[1:nlatent,statei] = (( sDRIFT * state[1:nlatent] + sCINT[,1]) - base)/1e-6;
            }
          ;

          discreteDRIFT=append_row(append_col(sDRIFT,sCINT),rep_matrix(0,1,nlatent+1));
          discreteDRIFT[nlatent+1,nlatent+1] = 1;
          etacov = quad_form(etacov, J');
          etacov[1:nlatent,1:nlatent] += sDIFFUSION;
          if(intoverstates==0) discreteDIFFUSION = cholesky_decompose(discreteDIFFUSION);
          eta[1:nlatent] = (discreteDRIFT * append_row(eta[1:nlatent],1.0))[1:nlatent];
        }
      } // end of non t0 time update
  
  
    if(nlmeasurement==1 || ntdpred > 0 || T0check[rowi]==1){ //ukf time update
  
      if(T0check[rowi]==1) {
        if(intoverpop==1) sigpoints[(nlatent+1):(nlatentpop), (nlatent+1):(nlatentpop)] = rawpopcovsqrt * sqrtukfadjust;
        sigpoints[1:nlatent,1:nlatent] = sT0VAR * sqrtukfadjust;
      }
      
      if(T0check[rowi]==0)  sigpoints = cholesky_decompose(makesym(etacov)) * sqrtukfadjust;
    
      //configure ukf states
      for(statei in 2:cols(ukfstates) ){ //for each ukf state sample
  
          state = eta; 
          if(statei > (2+nlatentpop)){
            state += -sigpoints[,statei-(2+nlatentpop)];
          } else
          if(statei > 2) state += sigpoints[,statei-2]; 

        if(T0check[rowi]==1){
          ;
      if(intoverpop==1){
        
    for(ri in 1:size(T0MEANSsetup)){
      if(T0MEANSsetup[ ri,5] > 0){ 
         sT0MEANS[T0MEANSsetup[ ri,1], T0MEANSsetup[ri,2]] = tform(state[nlatent +T0MEANSsetup[ri,5] ], T0MEANSsetup[ri,4], T0MEANSvalues[ri,2], T0MEANSvalues[ri,3], T0MEANSvalues[ri,4] ); 
      }
    }

    for(ri in 1:size(T0VARsetup)){
      if(T0VARsetup[ ri,5] > 0){ 
         sT0VAR[T0VARsetup[ ri,1], T0VARsetup[ri,2]] = tform(state[nlatent +T0VARsetup[ri,5] ], T0VARsetup[ri,4], T0VARvalues[ri,2], T0VARvalues[ri,3], T0VARvalues[ri,4] ); 
      }
    }};
          state[1:nlatent] += sT0MEANS[,1];
        } 
        ;
        if(ntdpred > 0) state[1:nlatent] +=   (sTDPREDEFFECT * tdpreds[rowi]); //tdpred effect only influences at observed time point
        ukfstates[, statei] = state; //now contains time updated state
        if(statei==2 && ukffull==1) ukfstates[, 1] = state; //mean goes in twice for weighting
      }
  
      if(ukffull == 1) {
        eta = colMeans(ukfstates');
        etacov = cov_of_matrix(ukfstates') / asquared;
      }
      if(ukffull == 0){
        eta = ukfstates[,2];
        etacov = tcrossprod(ukfstates[,3:(nlatentpop+2)] - rep_matrix(ukfstates[,2],nlatentpop)) /asquared / (nlatentpop*2+1);
      }
    } //end ukf if necessary time update
  } // end non linear time update


  if(savescores==1) kout[rowi,(nmanifest*2+1):(nmanifest*2+nlatent)] = eta;
if(verbose > 1) print("etaprior = ", eta, " etapriorcov = ",etacov);

    if(intoverstates==0 && lineardynamics == 1) {
      if(T0check[rowi]==1) eta += cholesky_decompose(sT0VAR) * etaupdbasestates[(1+(rowi-1)*nlatent):(rowi*nlatent)];
      if(T0check[rowi]==0) eta +=  discreteDIFFUSION * etaupdbasestates[(1+(rowi-1)*nlatent):(rowi*nlatent)];
    }

    if (nobs_y[rowi] > 0) {  // if some observations create right size matrices for missingness and calculate...
    
      int o[nobs_y[rowi]]; //which indicators are observed
      int o1[nbinary_y[rowi]]; //which indicators are observed and binary
      int o0[ncont_y[rowi]]; //which indicators are observed and continuous
      o = whichobs_y[rowi,1:nobs_y[rowi]]; //which obs are not missing in this row
      o1 = whichbinary_y[rowi,1:nbinary_y[rowi]];
      o0 = whichcont_y[rowi,1:ncont_y[rowi]];

      if(nlmeasurement==0){ //non ukf measurement
        if(intoverstates==1) { //classic kalman
          ypred[o] = sMANIFESTMEANS[o,1] + sLAMBDA[o,] * eta[1:nlatent];
          if(nbinary_y[rowi] > 0) ypred[o1] = to_vector(inv_logit(to_array_1d(sMANIFESTMEANS[o1,1] +sLAMBDA[o1,] * eta[1:nlatent])));
          ypredcov[o,o] = quad_form(etacov[1:nlatent,1:nlatent], sLAMBDA[o,]') + sMANIFESTVAR[o,o];
          for(wi in 1:nmanifest){ 
            if(manifesttype[wi]==1 && Y[rowi,wi] != 99999) ypredcov[wi,wi] += fabs((ypred[wi] - 1) .* (ypred[wi]));
            if(manifesttype[wi]==2 && Y[rowi,wi] != 99999) ypredcov[wi,wi] += square(fabs((ypred[wi] - round(ypred[wi])))); 
          }
          K[,o] = mdivide_right(etacov * append_row(sLAMBDA[o,]',rep_matrix(0,nlatentpop-nlatent,nmanifest)[,o]), ypredcov[o,o]); 
          etacov += -K[,o] * append_col(sLAMBDA[o,],rep_matrix(0,nmanifest,nlatentpop-nlatent)[o,]) * etacov;
        }
        if(intoverstates==0) { //sampled states
          if(ncont_y[rowi] > 0) {
            ypred[o0] = sMANIFESTMEANS[o0,1] + sLAMBDA[o0,] * eta[1:nlatent];
            if(ncont_y[rowi] > 0) ypredcov_sqrt[o0,o0] = sMANIFESTVAR[o0,o0];
          }
          if(nbinary_y[rowi] > 0) ypred[o1] = to_vector(inv_logit(to_array_1d(sMANIFESTMEANS[o1,1] +sLAMBDA[o1,] * eta[1:nlatent])));
        }
      } 
  

      if(nlmeasurement==1){ //ukf measurement
        vector[nlatentpop] state; //dynamic portion of current states
        matrix[nmanifest,cols(ukfmeasures)] merrorstates;

        for(statei in 2:cols(ukfmeasures)){
          state = ukfstates[, statei];
          ;
      if(intoverpop==1){
        
    for(ri in 1:size(LAMBDAsetup)){
      if(LAMBDAsetup[ ri,5] > 0){ 
         sLAMBDA[LAMBDAsetup[ ri,1], LAMBDAsetup[ri,2]] = tform(ukfstates[nlatent +LAMBDAsetup[ri,5], statei ], LAMBDAsetup[ri,4], LAMBDAvalues[ri,2], LAMBDAvalues[ri,3], LAMBDAvalues[ri,4] ); 
      }
    }

    for(ri in 1:size(MANIFESTMEANSsetup)){
      if(MANIFESTMEANSsetup[ ri,5] > 0){ 
         sMANIFESTMEANS[MANIFESTMEANSsetup[ ri,1], MANIFESTMEANSsetup[ri,2]] = tform(ukfstates[nlatent +MANIFESTMEANSsetup[ri,5], statei ], MANIFESTMEANSsetup[ri,4], MANIFESTMEANSvalues[ri,2], MANIFESTMEANSvalues[ri,3], MANIFESTMEANSvalues[ri,4] ); 
      }
    }

    for(ri in 1:size(MANIFESTVARsetup)){
      if(MANIFESTVARsetup[ ri,5] > 0){ 
         sMANIFESTVAR[MANIFESTVARsetup[ ri,1], MANIFESTVARsetup[ri,2]] = tform(ukfstates[nlatent +MANIFESTVARsetup[ri,5], statei ], MANIFESTVARsetup[ri,4], MANIFESTVARvalues[ri,2], MANIFESTVARvalues[ri,3], MANIFESTVARvalues[ri,4] ); 
      }
    }

    for(ri in 1:size(PARSsetup)){
      if(PARSsetup[ ri,5] > 0){ 
         sPARS[PARSsetup[ ri,1], PARSsetup[ri,2]] = tform(ukfstates[nlatent +PARSsetup[ri,5], statei ], PARSsetup[ri,4], PARSvalues[ri,2], PARSvalues[ri,3], PARSvalues[ri,4] ); 
      }
    }};

  
          ukfmeasures[, statei] = sMANIFESTMEANS[,1] + sLAMBDA * state[1:nlatent];
          if(nbinary_y[rowi] > 0) {
            ukfmeasures[o1 , statei] = to_vector(inv_logit(to_array_1d(ukfmeasures[o1 , statei])));
          }
        
        merrorstates[,statei] = diagonal(sMANIFESTVAR);
        for(wi in 1:nmanifest){ 
          if(manifesttype[wi]==1 && Y[rowi,wi] != 99999) merrorstates[wi,statei] = sMANIFESTVAR[wi,wi] + fabs((ukfmeasures[wi,statei] - 1) .* (ukfmeasures[wi,statei])); //sMANIFESTVAR[wi,wi] + (merror[wi] / cols(ukfmeasures) +1e-8);
          if(manifesttype[wi]==2 && Y[rowi,wi] != 99999) merrorstates[wi,statei] = sMANIFESTVAR[wi,wi] + square(fabs((ukfmeasures[wi,statei]- round(ukfmeasures[wi,statei])))); 
        }
          
          if(statei==2 && ukffull == 1) { 
            merrorstates[,1] = merrorstates[,2];
            ukfmeasures[ , 1] = ukfmeasures [,2];
          }
        } 
        if(ukffull == 1) {
          ypred[o] = colMeans(ukfmeasures[o,]'); 
          ypredcov[o,o] = cov_of_matrix(ukfmeasures[o,]') /asquared + diag_matrix(colMeans(merrorstates[o,]')); //
          K[,o] = mdivide_right(crosscov(ukfstates', ukfmeasures[o,]') /asquared, ypredcov[o,o]); 
        }
        if(ukffull == 0){
          ypred[o] = ukfmeasures[o,2];
          for(ci in 3:cols(ukfmeasures)) ukfmeasures[o,ci] += -ukfmeasures[o,2];
          for(ci in 3:cols(ukfstates)) ukfstates[,ci] += -ukfstates[,2];
          ypredcov[o,o] = tcrossprod(ukfmeasures[o,3:(nlatentpop+2)]) /asquared / (nlatentpop*2+1) + diag_matrix(merrorstates[o,2]);
          K[,o] = mdivide_right(ukfstates[,3:cols(ukfstates)] * ukfmeasures[o,3:cols(ukfmeasures)]' /asquared / (nlatentpop*2+1), ypredcov[o,o]); 
        }
        etacov +=  - quad_form(ypredcov[o,o],  K[,o]');
      } //end ukf measurement


      if(ncont_y[rowi] > 0) ypredcov_sqrt[o0,o0]=cholesky_decompose(makesym(ypredcov[o0, o0])); //use o0, or o0?
        if(ncont_y[rowi] > 0) Ygen[ rowi, o0] = ypred[o0] + ypredcov_sqrt[o0,o0] * Ygenbase[rowi,o0]; //multi_normal_cholesky_rng(ypred[o0], ypredcov_sqrt[o0,o0]);
        if(nbinary_y[rowi] > 0) for(obsi in 1:size(o1)) Ygen[rowi, o1[obsi]] = ypred[o1[obsi]] > Ygenbase[rowi,o1[obsi]] ? 1 : 0; //bernoulli_rng(ypred[o1[obsi]]);
        err[o] = Ygen[rowi,o] - ypred[o]; // prediction error
      

      if(intoverstates==1) eta +=  (K[,o] * err[o]);
  
      
    }//end nobs > 0 section
  if(savescores==1) kout[rowi,(nmanifest*2+nlatent+1):(nmanifest*2++nlatent+nlatent)] = eta;
}//end rowi


for(rowi in 1:ndatapoints){
  for(oi in 1:nmanifest) Ygen[rowi,oi] = 99999;
}
 
}}


rawpopcov = tcrossprod(rawpopcovsqrt);
rawpopcorr = quad_form_diag(rawpopcov,inv_sqrt(diagonal(rawpopcov)));

popsd = rep_vector(0,nparams);
{
vector[nparams] rawpopsdfull;
rawpopsdfull[indvaryingindex] = rawpopsd; //base for calculations

    for(ri in 1:dims(popsetup)[1]){
      if(popsetup[ri,3] !=0) {

        popmeans[popsetup[ ri,3]] = tform(rawpopmeans[popsetup[ri,3] ], popsetup[ri,4], popvalues[ri,2], popvalues[ri,3], popvalues[ri,4] ); 

        popsd[popsetup[ ri,3]] = popsetup[ ri,5] ? 
          fabs(tform(
            rawpopmeans[popsetup[ri,3] ]  + rawpopsdfull[popsetup[ ri,3]], popsetup[ri,4], popvalues[ri,2], popvalues[ri,3], popvalues[ri,4]) -
           tform(
            rawpopmeans[popsetup[ri,3] ]  - rawpopsdfull[popsetup[ ri,3]], popsetup[ri,4], popvalues[ri,2], popvalues[ri,3], popvalues[ri,4]) ) /2 : 
          0; 

        if(ntipred > 0){
          for(tij in 1:ntipred){
            if(TIPREDEFFECTsetup[popsetup[ri,3],tij] ==0) {
              linearTIPREDEFFECT[popsetup[ri,3],tij] = 0;
            } else {
            linearTIPREDEFFECT[popsetup[ri,3],tij] = (
              tform(rawpopmeans[popsetup[ri,3] ] + TIPREDEFFECT[popsetup[ri,3],tij] * .01, popsetup[ri,4], popvalues[ri,2], popvalues[ri,3], popvalues[ri,4] ) -
              tform(rawpopmeans[popsetup[ri,3] ] - TIPREDEFFECT[popsetup[ri,3],tij] * .01, popsetup[ri,4], popvalues[ri,2], popvalues[ri,3], popvalues[ri,4] )
              ) /2 * 100;
            }
         }
        }
      }
    }
}
}
