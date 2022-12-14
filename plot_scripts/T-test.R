#Run a T test----

library(dplyr)
library(readxl)
#library(tidyverse)
#library(ggpubr)
#library(rstatix)

#setwd(path to data) 
setwd('/Users/Stella/OneDrive - University of Massachusetts/Documents/IGEA/Munge/igea22/water_scripts/')


#read in file
Sub=readRDS('avgEP_g12.rds')#%>%
  #filter(Xlabel==1 | Xlabel==2 | Xlabel==3 | Xlabel==4) #data set 1 to be compared in t test
  #filter(Xlabel==1)
var(Sub$avgO)

Notsub=readRDS('avgTP_g12.rds')#%>%
  #filter(Xlabel=='S') #data set 2 to be compared
var(Notsub$avgO)  

result=t.test(Sub$avgO, Notsub$avgO, var.equal=F) #t test for the alt columns of two sets of data to be compared

p=result$p.value
saveRDS(p, 'C:/Users/Stella/OneDrive - University of Massachusetts/Documents/IGEA/Munge/igea22/outputs/T_test/P_Values/Oxygen_EPe_TPe_p.rds')




#--------------------