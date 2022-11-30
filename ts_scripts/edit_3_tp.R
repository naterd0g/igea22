# script to read in raw data and organize it
library(dplyr)
library(readxl)
library(tidyr)
library(stringr)
library(stringi)

setwd('/Users/emmaboudreau/Documents/GitHub/igea22/')


g3_files = list.files('outputs/munged_3/')
#input_file = "ALT_TP06.rds"

edit_function = function(input_file){
  
  reach_ID = substring(toupper(strsplit(input_file, "_")[[1]][2]), 1, 4)
  
  master = readRDS(paste0('outputs/munged_3/TPs/master_',reach_ID,'.rds'))
  alt_df = readRDS(paste0('outputs/munged_3/TPs/ALT_',reach_ID,'.rds'))
  
  
  # edit the data to exclude all submerged water points----
  
  tundra_points = alt_df%>%
    filter(LRW != 'W')%>%
    mutate(Xlabel = Number)
  
  bank_points = alt_df%>%
    filter(LRW =='W')%>%
    filter(XSection != '2')%>%
    filter(XSection != '5')%>%
    filter(Number != '2')%>%
    mutate(Xlabel = as.double('0'))
  
  land_points = rbind(tundra_points, bank_points)
  
  # ----
  
  
  # edit the data to only have submerged water points----
  submerged_points = anti_join(alt_df, land_points)%>%
    mutate(Xlabel = 'S')
  
  
  #create final df
  ALT_violin = rbind(land_points, submerged_points)
  
  saveRDS(ALT_violin, paste0('outputs/munged_3/TP_violin/ALT_violin_',reach_ID,'.rds'))
  
  # ----
  
  
}

dummy = lapply(g3_files,edit_function)

