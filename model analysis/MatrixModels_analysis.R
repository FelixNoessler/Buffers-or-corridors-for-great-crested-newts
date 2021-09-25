
######################
##
##  Lecture on Matrix Population Models - Accompanying R Script
##
#####################3


## This script contains the R code needed to reproduce the example from the lecture.



## 1.) Define objects according to the example from the lecture (slide 21)

# Transition matrix: 

trans_mat <- matrix(c(  0,  .5, 1.2,
					   .4,   0,   0,
					    0,  .7, .8),
					nrow = 3, byrow = T)

matrix( 0, nrow=16, ncol=16, byrow = T )

trans_mat <- matrix(c(0,0,0, 4.5,
         0.39,0, 0, 0,
         0, 0.39, 0, 0,
         0, 0, 0.39, 0.76), ncol=4, nrow=4, byrow=T)





# Example state x_t:

state_xt <- c(40, 20, 15, 10)


## 2.) Let one time step pass (slide 27)

# Multiply transition matrix with the current state to get the state of next time step:
# (Note that we need a special operator to perform matrix multiplication)

(state_xtplus1 <- trans_mat %*% state_xt)


## 3.) Create a time series (slide 29)

# Let our example state from above be the initial state x0:
state_ts <- as.matrix(state_xt)

# And do repeated matrix multiplication with the transition matrix:
nr_years <- 15
for(t in 1:nr_years){
	state_ts <- cbind(state_ts, trans_mat %*% state_ts[,t])
}

# Now plot:
nr_stages <- dim(trans_mat)[1]
{
	plot(0:nr_years, state_ts[1,], type = "b", col = 1, 
		 xlab = "time step",
		 ylab = "Population count", ylim = c(0, max(state_ts)),
		 main = "Time series of matrix model")
	for(s in 2:nr_stages){
		lines(0:nr_years, state_ts[s,], type = "b", col = s)
	}
	legend("topleft", 
		   legend = paste0("stage-",1:nr_stages),
		   col = 1:nr_stages, lty = 1)
}


## 4.) Eigen analysis of transition matrix

# Use the built-in R function for Eigen analysis:
trans_mat_Eigen <- eigen(trans_mat)

# The resulting object contains the eigenvectors and their corresponding eigenvalues.
# In this step we will use the eigenvalues only and look at the eigenvectors in the next step:

(trans_mat_EValues <- trans_mat_Eigen$values)

# Determine the asymptotic growth rate (leading eigenvalue):
(growth_rate <- Re(trans_mat_EValues[1]))


## 5.) Stable age/stage distribution

# Get first eigenvector
stable_dist <- trans_mat_Eigen$vectors[,1]

# Get rid of imaginary part
stable_dist <- Re(stable_dist)

# Normalise
(stable_dist <- stable_dist/sum(stable_dist))


## 6.) Sensitivity & Elasticity

# There is an R package for the analysis of transition matrices in R: 
# 'popbio: Construction and Analysis of Matrix Population Models'

# We will calculate sensitivity and elasticity by hand:

# Get the leading left eigenvector as the eigenvector of the transposed transition matrix:
lev <- t(eigen(t(trans_mat))$vectors[,1])

# Calculate sensitivity as the outer product of the transposed conjugate left eigenvector 
# and the right eigenvector (both corresponding to the dominant eigenvalue), normalised
# by their inner product:
sensity <- (t(Re(lev)) %*% stable_dist) / as.numeric(Re(lev) %*% stable_dist)

# Then, the elasticity is the inverse asymptotic growth rate times the matrix product
# of sensitivity and transition matrix:
(elasty <- (trans_mat/ growth_rate) * sensity )



#--------------------------------------------------------------------------------


## Exercise
#------------------

# The Lynx example:


## 1.) Define transition matrix and initial state

(trans_mat <- matrix(c(0, 0.53, 0, 0, 0, 0.63, 5, 0, 0.8), 
					 nrow = 3, byrow = F))

state_xt <- c( 3, 2, 1 )


## Do steps 2.) to 5.) yourself, using the code above!

