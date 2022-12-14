#script for group 1 and 2 WS data analysis
#libraries and wd----
library(dplyr)
library(readxl)
library(tidyr)
library(stringr)
library(fuzzyjoin)
library(gmt)
library(rgdal)
library(sf)

setwd('/Users/Oskar/Documents/UMass/IGEA/igea22/')

#group12 raw water data reading-in and normalization----
WS1_df = read_xlsx('Raw_water_data/12WS.xlsx')

#select and rename columns
WS1_clean_df=WS1_df%>%
  select('Line', 'd(18_16)Mean', 'd(D_H)Mean', 'Ignore', 'Identifier_1', 'Identifier_2')%>%
  rename("meanO"="d(18_16)Mean")%>%
  rename("meanH"="d(D_H)Mean")%>%
  filter(Line >= 323)%>%
  filter(Line <= 580)%>%
  filter(Ignore == 0)

#create df for normalizing
WS1_stand_df=WS1_clean_df%>%
  filter(Identifier_2 == "standard")%>%
  mutate(standardO=case_when(Identifier_1 == "Picarro zero 1 6_23_22" | Identifier_1 == "Picarro zero 2 6_23_22" | Identifier_1 == "Picarro zero 3 6_23_22"~.3,
                             Identifier_1 == "Picarro mid 3 6_23_22" | Identifier_1 == "Picarro mid 2 6_23_22"| Identifier_1 == "Picarro mid 1 6_23_22"~-20.6,
                             Identifier_1 == "Picarro depl 3 6_23_22" | Identifier_1 == "Picarro depl 2 6_23_22"| Identifier_1 == "Picarro depl 1 6_23_22"~-29.6,))%>%
  mutate(standardH=case_when(Identifier_1 == "Picarro zero 1 6_23_22" | Identifier_1 == "Picarro zero 2 6_23_22" | Identifier_1 == "Picarro zero 3 6_23_22"~1.8,
                           Identifier_1 == "Picarro mid 3 6_23_22" | Identifier_1 == "Picarro mid 2 6_23_22"| Identifier_1 == "Picarro mid 1 6_23_22"~-159,
                           Identifier_1 == "Picarro depl 3 6_23_22" | Identifier_1 == "Picarro depl 2 6_23_22"| Identifier_1 == "Picarro depl 1 6_23_22"~-235,))

#linear regressions
modelO = lm(formula = standardO ~ meanO, data = WS1_stand_df)
modelH = lm(formula = standardH ~ meanH, data = WS1_stand_df)

#create normalized df
WS1_norm_df=WS1_clean_df%>%
  filter(Identifier_2=="sample")%>%
  mutate(normO=modelO$coefficients[2]*meanO+modelO$coefficients[1])%>%
  mutate(normH=modelH$coefficients[2]*meanH+modelH$coefficients[1])

#average isotope ratios and join with metadata----
WS1_avg_df = WS1_norm_df%>%
  group_by(Identifier_1)%>%
  summarize(avgO=mean(normO),avgH=mean(normH))

#join averages with metadata
metadata_df = read_xlsx('Raw_water_data/12metadata.xlsx')%>%
  mutate(newtime = sapply(strsplit(as.character(Sample_Time), " "),"[",2))%>%
  mutate(newdate = paste(Date, newtime, sep = " "))%>%
  mutate(date_time=as.POSIXct(newdate,tz="US/Alaska"))%>%
  mutate(doy=as.numeric(strftime(date_time, format = "%j")))

our_df = left_join(WS1_avg_df,metadata_df,"Identifier_1")

#combining groups 1, 2, and 3----
our3=readRDS('water_scripts/our3.rds')
ours=rbind(our_df,our3)

#comparing average isotope fractions for all 4 permutations of classification and season----
avgEP_g12=our_df%>%
  filter(substr(Identifier_1, 1, 1) == "E")%>%
  mutate(perm="EP.g12")

avgEP_g3=our3%>%
  filter(substr(Identifier_1, 1, 1) == "E")%>%
  mutate(perm="EP.g3")

avgTP_g12=our_df%>%
  filter(substr(Identifier_1, 1, 1) == "T")%>%
  mutate(perm="TP.g12")

avgTP_g3=our3%>%
  filter(substr(Identifier_1, 1, 1) == "T")%>%
  mutate(perm="TP.g3")

avg_perm=rbind(avgEP_g12,avgEP_g3,avgTP_g12,avgTP_g3)%>%
  group_by(perm)%>%
  summarize(avgO=mean(avgO),avgH=mean(avgH))

saveRDS(avgEP_g12,'water_scripts/avgEP_g12.rds')
saveRDS(avgEP_g3,'water_scripts/avgEP_g3.rds')
saveRDS(avgTP_g12,'water_scripts/avgTP_g12.rds')
saveRDS(avgTP_g3,'water_scripts/avgTP_g3.rds')

#read in NEON data----
ground_df = read_xlsx('Raw_water_data/NEON_ground_111622.xlsx')%>%
  select('Latitude','Longitude','Elevation_mabsl','Sample_ID','Collection_Date','d2H','d18O')%>%
  mutate(date_time=as.POSIXct(Collection_Date,tz="US/Alaska"))%>%
  mutate(doy=as.numeric(strftime(date_time, format = "%j")))%>%
  mutate(d2H=as.numeric(d2H))%>%
  mutate(d18O=as.numeric(d18O))

precip_df = read_xlsx('Raw_water_data/NEON_precipitation.xlsx',sheet=2, skip=1)%>%
  select('Latitude','Longitude','Elevation_mabsl','Sample_ID','Collection_Date','d2H','d18O')%>%
  mutate(date_time=as.POSIXct(Collection_Date,tz="US/Alaska"))%>%
  mutate(doy=as.numeric(strftime(date_time, format = "%j")))%>%
  mutate(d2H=as.numeric(d2H))%>%
  mutate(d18O=as.numeric(d18O))

#filter for North Slope----
ground_NS_df = ground_df%>%
  filter(between(Latitude,68,69))%>%
  mutate(Site_ID=case_when(Longitude < -149.4~"TOOK",
                           Longitude >= -149.4~"OKSR"))

precip_NS_df = precip_df%>%
  filter(between(Latitude,68,69))

#convert into utm----
LongLatToUTM<-function(x,y,zone){
  xy <- data.frame(ID = 1:length(x), X = x, Y = y)
  coordinates(xy) <- c("X", "Y")
  proj4string(xy) <- CRS("+proj=longlat +datum=WGS84")
  res <- spTransform(xy, CRS(paste("+proj=utm +zone=",zone," ellps=WGS84",sep='')))
  res=st_as_sf(res)
  return(data.frame(x=st_coordinates(res)[,1],y=st_coordinates(res)[,2]))}

ground_utm = ground_NS_df%>%
  mutate(LongLatToUTM(Longitude,Latitude,6))

precip_utm = precip_NS_df%>%
  mutate(LongLatToUTM(Longitude,Latitude,6))
  
#join to NEON's precipitation data by closest times and coordinates----
by_time_precip=difference_left_join(ours,precip_utm,by='doy',max_dist=365,distance_col='days_apart')

near_t_precip=by_time_precip%>%
  group_by(Identifier_1)%>%
  filter(days_apart==min(days_apart))

inv_t_precip=by_time_precip%>%
  mutate(w=1/days_apart)%>%
  group_by(Identifier_1)%>%
  summarize(precipH=weighted.mean(d2H,w),precipO=weighted.mean(d18O,w))

#fix NaN due to ours and Neon's taken on the same day
inv_t_precip$precipH[is.na(inv_t_precip$precipH)]=-146.4834
inv_t_precip$precipO[is.na(inv_t_precip$precipO)]=-18.47599

#join to NEON's ground data by closest times and coordinates----
by_dist_ground=distance_left_join(ours,ground_utm,by=c("x","y"),max_dist=100000,distance_col='meters_apart')

bdg_vis=by_dist_ground%>%
  select('Identifier_1','Sample_ID','meters_apart')

ground_OKSR=ground_utm%>%
  filter(Site_ID=='OKSR')

bdg_OKSR=distance_left_join(ours,ground_OKSR,by=c("x","y"),max_dist=100000,distance_col='meters_apart')%>%
  group_by(Identifier_1)%>%
  summarize(meters_to_ground=mean(meters_apart))

btg_OKSR=difference_left_join(ours,ground_OKSR,by='doy',max_dist=365,distance_col='days_apart')%>%
  mutate(w=1/days_apart)%>%
  group_by(Identifier_1)%>%
  summarize(ourO=first(avgO),ourH=first(avgH),groundH=weighted.mean(d2H,w),groundO=weighted.mean(d18O,w))

#fix NaN due to ours and Neon's taken on the same day
g_OKSR_avgs=ground_OKSR%>%
  filter(doy==229|doy==230)%>%
  group_by(doy)%>%
  summarize(g_H_avg=mean(d2H),g_O_avg=mean(d18O))

btg_OKSR$groundH[15]=g_OKSR_avgs$g_H_avg[1]
btg_OKSR$groundO[15]=g_OKSR_avgs$g_O_avg[1]
btg_OKSR$groundH[28]=g_OKSR_avgs$g_H_avg[2]
btg_OKSR$groundO[28]=g_OKSR_avgs$g_O_avg[2]

#putting it all together----
g_from_OKSR=left_join(btg_OKSR,bdg_OKSR,by='Identifier_1')

from_OKSR=left_join(g_from_OKSR,inv_t_precip,by='Identifier_1')

final_OKSR=from_OKSR%>%
  mutate(fO_precip=(groundO-ourO)/(groundO-precipO))%>%
  mutate(fO_ground=(ourO-precipO)/(groundO-precipO))%>%
  mutate(fH_precip=(groundH-ourH)/(groundH-precipH))%>%
  mutate(fH_ground=(ourH-precipH)/(groundH-precipH))

