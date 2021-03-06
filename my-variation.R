# I added in schools, where there are just 4 schools for every 100 squares on the grid. The schools are visualized in yellow, and they do not relocate during the simulation. Both population groups want to locate near the schools, but one has privilege over the other. This is group one (red), which also has a larger proportion of agents.

# I built a function school.locations(grid) to return a list of school locations, which I ended up not actually using. In similarity.to.center(grid.subset,center.val,row,col), I had individuals from group one return a value of 0, so that they absolutely have to move, when they are not located near a school (with distance radius). Individuals from group two, the disadvantaged group, return a value that is smaller than before, by setting same = same/2. I test whether an individual is near a school within a radius using the function near2school(row,col,radius). 

# We can see the results of the simulation are the same type of segregation, but that red neighborhoods are more centered around a higher concentration of schools than the blue neighborhoods. This somewhat mimics school choice and access as a function of location choice and privilege.


# model parameters ####
rows <- 50 
cols <- 50
proportion.group.1 <- .5 # proportion of red agents
non.residential <- .25 # proportion of grid that will be empty space or schools
min.similarity <- 4/8 # minimum proportion of neighbors that are the same type to not move
radius = 3 #radius is num of blocks that they can be away from school to be considered near a school

# create.grid ####
# generates a rows x column matrix and randomly places the initial population
# values in the matrix are either 0, 1, or 2
# if 0, the space is empty
# 1 and 2 represent the two different groups
create.grid <- function(rows, cols, proportion.group.1, non.residential){
  pop.size.group.1 <- (rows*cols)*(1-non.residential)*proportion.group.1
  pop.size.group.2 <- (rows*cols)*(1-non.residential)*(1-proportion.group.1)
  init.empty <- (rows*cols)-pop.size.group.1-pop.size.group.2
  schools <- rows*cols/100*4
  empty <- init.empty - schools
  if(!empty>0){ break; }
  
  initial.population <- sample(c(
    rep(1, pop.size.group.1), 
    rep(2, pop.size.group.2), 
    rep(0, empty),
    rep(3,schools)
  ))
  grid <- matrix(initial.population, nrow=rows, ncol=cols)
}

# visualize.grid ####
# outputs a visualization of the grid, with red squares representing group 1,
# blue squares group 2, yellow squares as schools, and white squares empty locations.
visualize.grid <- function(grid){
  image(grid, col=c('white','red','blue','yellow'), xaxs=NULL, yaxs=NULL, xaxt='n', yaxt='n')
        #xaxs=NULL, yaxs=NULL, xaxt='n', yaxt='n', xlab="Yellow: Schools, Red: Dominant Group")
  title(main = "Yellow: Schools, Red: Dominant Group", sub = NULL, xlab = NULL, ylab = NULL,
        line = NA, outer = FALSE)
  #axis( 1, at=NULL, labels= c("Yellow: Schools, Red: Dominant Group"), tic = FALSE)
}

## testing visualize.grid
# newgrid <- create.grid(rows, cols, proportion.group.1, empty)
# visualize.grid(newgrid)

# empty.locations ####
# returns all the locations in the grid that are empty
# output is an N x 2 array, with N equal to the number of empty locations
# the 2 columns contain the row and column of the empty location.
empty.locations <- function(grid){
  return(which(grid==0, arr.ind=T))
}

school.locations <- function(grid){
  return(which(grid==3, arr.ind=T))
}

# similarity.to.center ####
# takes a grid and the center.val of that grid and returns
# the proportion of cells that are the same as the center,
# ignoring empty cells. the center.val must be specified
# manually in case the grid has an even number of rows or 
# columns

similarity.to.center <- function(grid.subset, center.val,row,col){
  if(center.val == 0){ return(NA) }
  same <- sum(grid.subset==center.val) - 1
  not.same <- sum(grid.subset!=center.val) - sum(grid.subset==0)
  if(center.val == 1 && !near2school(row,col,radius)){
    same = 0 #if the individual is part of the dominant group and is not near a school, return that they absolutely have to move
  }
  if(center.val == 2 && !near2school(row,col,radius)){
    same = same/2 #if the individual is part of non-dominant group and is not near a school, make them more unhappy
  }
  return(same/(same+not.same))
}

near2school <- function(row,col,radius){
  grid.subset = grid[max(0, row-radius):min(rows,row+radius), max(0,col-radius):min(cols,col+radius)]
  output = FALSE
  for (r in 1:nrow(grid.subset)){
    for (c in 1:ncol(grid.subset)){
      if(grid.subset[r,c]==3){
        output = TRUE
        break
      }
    }
  }
  return(output)
}

# segregation ####
# computes the proportion of neighbors who are from the same group
# changed to account for schools also not adding to the segregation value
segregation <- function(grid){
  same.count <- 0
  diff.count <- 0
  for(row in 1:(nrow(grid)-1)){
    for(col in 1:(ncol(grid)-1)){
      if((grid[row,col] != 0 || grid[row,col] != 3) && 
         (grid[row+1,col+1] != 0 || grid[row+1,col+1] != 3)){
        if(grid[row,col] != grid[row+1,col+1]){
          diff.count <- diff.count + 1
        } else {
          same.count <- same.count + 1
        }
      }
    }
  }
  return(same.count / (same.count + diff.count))
}

# unhappy.agents ####
# takes a grid and a minimum similarity threshold and computes
# a list of all of the agents that are unhappy with their 
# current location. the output is N x 2, with N equal to the
# number of unhappy agents and the columns representing the 
# location (row, col) of the unhappy agent in the grid
#edited to be specific to group.type
unhappy.agents <- function(grid, min.similarity,group.type){
  grid.copy <- grid
  for(row in 1:rows){
    for(col in 1:cols){
      similarity.score <- similarity.to.center(grid[max(0, row-1):min(rows,row+1), max(0,col-1):min(cols,col+1)], grid[row,col],row,col)
      if(is.na(similarity.score)){
        grid.copy[row,col] <- NA
      } else {
        if(grid[row,col] == group.type){
          grid.copy[row,col] <- similarity.score < min.similarity #assign true if want to move
        } else {
          grid.copy[row,col] <- NA
        }
      }
    }
  }
  return(which(grid.copy==TRUE, arr.ind = T))
}

# one.round ####
# runs a single round of the simulation. the round starts by finding
# all of the unhappy agents and empty spaces. then unhappy agents are randomly
# assigned to a new empty location. a new grid is generated to reflect all of
# the moves that took place.
one.round <- function(grid, min.similarity,group.type){
  #newgrid = grid
  need2Move = unhappy.agents(grid,min.similarity,group.type) 
  empty.loc = empty.locations(grid)
  #school.loc = school.locations(grid)
  newLocations = empty.loc[sample(1:nrow(empty.loc),nrow(empty.loc), replace=FALSE), ]
  for (i in 1:nrow(newLocations)){
    if(i>nrow(need2Move)){ break; }
    empty.x = newLocations[i,1]
    empty.y = newLocations[i,2]
    unhappy.x = need2Move[i,1]
    unhappy.y = need2Move[i,2]
    grid[empty.x,empty.y] = grid[unhappy.x,unhappy.y]
    grid[unhappy.x,unhappy.y] = 0
  }
  return(grid)
}

# running the simulation ####
done <- FALSE # a variable to keep track of whether the simulation is complete
grid <- create.grid(rows, cols, proportion.group.1, non.residential)
visualize.grid(grid)
seg.tracker <- c(segregation(grid)) # keeping a running tally of the segregation scores for each round
while(!done){
  new.grid.temp <- one.round(grid, min.similarity,1) # run one round of the simulation for the dominant group, and store output in new.grid.temp
  new.grid <- one.round(new.grid.temp, min.similarity,2) # run one round of the simulation for the non-dominant group, and store output in new.grid
  seg.tracker <- c(seg.tracker, segregation(grid)) # calculate segregation score and add to running list
  if(all(new.grid == grid)){ # check if the new.grid is identical to the last grid
    done <- TRUE # if it is, simulation is over -- no agents want to move
  } else {
    grid <- new.grid # otherwise, replace grid with new.grid, and loop again.
  }
}
layout(1:1)
#layout(1:2) # change graphics device to have two plots
visualize.grid(grid) # show resulting grid
plot(seg.tracker) # plot segregation over time

