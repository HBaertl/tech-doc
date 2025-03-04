# zooplankton analysis



#```{r, echo = T, eval = F}

#libraries
library(vegan)
library(stats)
library(mgcv)
library(reshape2)
library(readxl)
library(lubridate)
library(sp)
library(maptools)
library(marmap)
library(rgeos)


# load data
URL='ftp://ftp.nefsc.noaa.gov/pub/hydro/zooplankton_data/EcoMon_Plankton_Data_v3_0.xlsx'
ZPD=openxlsx::read.xlsx(URL, sheet='Data')
# Fix date, time
dt=as_date(ZPD$date, origin = "1899-12-30")
DOY=yday(dt) #day of year
month=as.numeric(format(dt, '%m'))
year=as.numeric(format(dt, '%Y'))
ZPD$year=year
ZPD$month=month
ZPD$dt=dt
ZPD$DOY=DOY
ZPD$day=as.numeric(format(dt, '%d'))
ZPD$lat2=ceiling(ZPD$lat) #use for binning into 1 degree bins for removal of undersampled bins
ZPD$lon2=floor(ZPD$lon) #use for binning into 1 degree bins for removal of undersampled bins
# ASSIGN EPU based on GPS data
## load shapefiles from EDAB EPU analysis ## not available here

gbk=readShapeSpatial("EPU_GBKPoly.shp")
gom=readShapeSpatial("EPU_GOMPoly.shp")
mab=readShapeSpatial("EPU_MABPoly.shp")
scs=readShapeSpatial("EPU_SCSPoly.shp")
#combine shapefiles GOM and GBK
gom.gbk.shp=gUnion(gom, gbk, byid=F, id=NULL)
gom.gbk.shp=gUnion(gom, gbk, byid=F, id=NULL)
gom.scs.shp=gUnion(gom, scs, byid=F, id=NULL)
mab.gbk.shp=gUnion(mab, gbk, byid=F, id=NULL)
NES.shp=gUnion(mab.gbk.shp, gom.scs.shp, byid=F, id=NULL)
#extract just lat/lons for lines
gbk.lonlat =as.data.frame(
  lapply(slot(gbk, "polygons"),
         function(x) lapply(slot(x, "Polygons"),
                            function(y) slot(y, "coords"))))
gom.lonlat =as.data.frame(
  lapply(slot(gom, "polygons"), 
         function(x) lapply(slot(x, "Polygons"), 
                            function(y) slot(y, "coords"))))
mab.lonlat =as.data.frame(
  lapply(slot(mab, "polygons"), 
         function(x) lapply(slot(x, "Polygons"), 
                            function(y) slot(y, "coords"))))
scs.lonlat =as.data.frame(
  lapply(slot(scs, "polygons"), 
         function(x) lapply(slot(x, "Polygons"), 
                            function(y) slot(y, "coords"))))
gom.gbk.lonlat =as.data.frame(
  lapply(slot(gom.gbk.shp, "polygons"), 
         function(x) lapply(slot(x, "Polygons"), 
                            function(y) slot(y, "coords"))))
NES.lonlat =as.data.frame(NES.shp@polygons[[1]]@Polygons[[1]]@coords)
# create matrix to use in in.out function
# create matrix to use in in.out function from package 'mgcv'
gom.mat=as.matrix(gom.lonlat)
gbk.mat=as.matrix(gbk.lonlat)
mab.mat=as.matrix(mab.lonlat)
scs.mat=as.matrix(scs.lonlat)
gom.gbk.mat=as.matrix(gom.gbk.lonlat)
# assign samples to EPU
m4=as.matrix(ZPD[,6:5]) #lon,lat from ZPD
ZPD$epu=NA
ZPD$epu[which(in.out(gbk.mat, m4))]='GBK'
ZPD$epu[which(in.out(gom.mat, m4))]='GOM'
ZPD$epu[which(in.out(scs.mat, m4))]='SCS'
ZPD$epu[which(in.out(mab.mat, m4))]='MAB'
test=ZPD[is.na(ZPD$epu),] #unassigned
nms=data.frame(colnames(ZPD)) # column names of orginal data
# limit data set to zooplankton from 1977 on
ZPDb=ZPD[,c(seq(1,14,1), seq(290,297,1), seq(106,197,1))] 
# check to make sure these are correct against 'nms' if data source changes!!!
ZPDb=ZPDb[order(ZPDb$date),]
ZPDb=ZPDb[which(ZPDb$year > 1976),] # remove NA data in years prior to 1977
# Select only taxa present in yearly data > x percent of samples
X=20 # percent criteria to use as minimum percent in samples
ZPDa=ZPDb
ZPDa=ZPDa[!is.na(ZPDa$zoo_gear),] # Remove NA in zooplankton rows
# Reduce to taxa occurrance > x percent in samples
p.a=ZPDa[,24:114]
p.a[p.a > 0]=1 # presence/absence
count=colSums(p.a)
pct=(count/dim(ZPDa)[1])*100
crit=which(pct>X)
ZPDa=ZPDa[c(1:23,crit+23)] # data limited to taxa occurring in > X percent of samples

#Take median date from each cruise and assign cruise to bimonth for bi-monthly means aggregation
cruises=unique(ZPDa$cruise_name)
for (i in 1:length(cruises)){
  ZPDa$medmonth[ZPDa$cruise_name == cruises[i]]=median(ZPDa$DOY[ZPDa$cruise_name == cruises[i]])
}
ZPDa$bmm=NA
ZPDa$bmm[which(as.integer(ZPDa$medmonth) %in% seq(0,59))]=1
ZPDa$bmm[which(as.integer(ZPDa$medmonth) %in% seq(60,120))]=3
ZPDa$bmm[which(as.integer(ZPDa$medmonth) %in% seq(121,181))]=5
ZPDa$bmm[which(as.integer(ZPDa$medmonth) %in% seq(182,243))]=7
ZPDa$bmm[which(as.integer(ZPDa$medmonth) %in% seq(244,304))]=9
ZPDa$bmm[which(as.integer(ZPDa$medmonth) %in% seq(305,366))]=11

ZPDa[,14]=as.numeric(ZPDa[,14])
ZPDa[,23]=as.numeric(ZPDa[,23])
ZPDsave=ZPDa #from above routine, Yearly (all data) 

SEASON='Yearly'
ZPDa=ZPDsave
# LOG transform data using ZPDa from above (select season first)
test=log10(ZPDa[,24:50]+1) #choose columns with zooplankton data
ZPDlog=ZPDa
ZPDlog[,24:50]=test
nm=matrix(colnames(ZPDlog))

area='GBK'
gbk.yr.spln=data.frame()
for (i in 23:50){
  num=i
  name=nm[num,1]
  mean.loc.x=aggregate(ZPDlog[which(ZPDlog$epu==area),num],
                       by=list(ZPDlog$bmm[which(ZPDlog$epu==area)]), 
                       FUN=mean, na.rm=T)
  func = splinefun(mean.loc.x[,1], y=mean.loc.x[,2], 
                   method="natural",  
                   ties = mean)  
  x.daily=func(seq(1, 12, 0.0302)) #365 days
  gbk.yr.spln=rbind(gbk.yr.spln,x.daily)
}
gbk.yr.spln=t(gbk.yr.spln)
rownames(gbk.yr.spln)=seq(1:365); colnames(gbk.yr.spln)=nm[23:50,1]

area='GOM'
gom.yr.spln=data.frame()
for (i in 23:50){
  num=i
  name=nm[num,1]
  mean.loc.x=aggregate(ZPDlog[which(ZPDlog$epu==area),num],
                       by=list(ZPDlog$bmm[which(ZPDlog$epu==area)]), 
                       FUN=mean, na.rm=T)
  func = splinefun(mean.loc.x[,1], y=mean.loc.x[,2], 
                   method="natural",  ties = mean)
  x.daily=func(seq(1, 12, 0.0302)) #365 days
  gom.yr.spln=rbind(gom.yr.spln,x.daily)
}
gom.yr.spln=t(gom.yr.spln)
rownames(gom.yr.spln)=seq(1:365); colnames(gom.yr.spln)=nm[23:50,1]

area='MAB'
mab.yr.spln=data.frame()
for (i in 23:50){
  num=i
  name=nm[num,1]
  mean.loc.x=aggregate(ZPDlog[which(ZPDlog$epu==area),num],
                       by=list(ZPDlog$bmm[which(ZPDlog$epu==area)]),
                       FUN=mean, na.rm=T)
  func = splinefun(mean.loc.x[,1], y=mean.loc.x[,2],
                   method="natural",  ties = mean)
  x.daily=func(seq(1, 12, 0.0302)) #365 days
  mab.yr.spln=rbind(mab.yr.spln,x.daily)
}
mab.yr.spln=t(mab.yr.spln)
rownames(mab.yr.spln)=seq(1:365); colnames(mab.yr.spln)=nm[23:50,1]

area='SCS'
scs.yr.spln=data.frame()
for (i in 23:50){
  num=i
  name=nm[num,1]
  mean.loc.x=aggregate(ZPDlog[which(ZPDlog$epu==area),num],
                       by=list(ZPDlog$bmm[which(ZPDlog$epu==area)]), 
                       FUN=mean, na.rm=T)
  func = splinefun(mean.loc.x[,1], y=mean.loc.x[,2], 
                   method="natural",  ties = mean)
  x.daily=func(seq(1, 12, 0.0302)) #365 days
  scs.yr.spln=rbind(scs.yr.spln,x.daily)
}
scs.yr.spln=t(scs.yr.spln)
rownames(scs.yr.spln)=seq(1:365); colnames(scs.yr.spln)=nm[23:50,1]

# Subtract mean expected value from observed abundance to get anomaly
gbk.anom=ZPDlog[which(ZPDlog$epu=='GBK'),]
gom.anom=ZPDlog[which(ZPDlog$epu=='GOM'),]
mab.anom=ZPDlog[which(ZPDlog$epu=='MAB'),]
scs.anom=ZPDlog[which(ZPDlog$epu=='SCS'),]

gbk.anom.b=data.frame(matrix(NA, nrow = dim(gbk.anom)[1], ncol = dim(gbk.anom)[2]))
for (i in 1:dim(gbk.anom)[1]){
  gbk.anom.b[i,23:50]=gbk.anom[i,23:50]-gbk.yr.spln[which(gbk.anom$DOY[i]==rownames(gbk.yr.spln)),]
}
gom.anom.b=data.frame(matrix(NA, nrow = dim(gom.anom)[1], ncol = dim(gom.anom)[2]))
for (i in 1:dim(gom.anom)[1]){
  gom.anom.b[i,23:50]=gom.anom[i,23:50]-gom.yr.spln[which(gom.anom$DOY[i]==rownames(gom.yr.spln)),]
}
mab.anom.b=data.frame(matrix(NA, nrow = dim(mab.anom)[1], ncol = dim(mab.anom)[2]))
for (i in 1:dim(mab.anom)[1]){
  mab.anom.b[i,23:50]=mab.anom[i,23:50]-mab.yr.spln[which(mab.anom$DOY[i]==rownames(mab.yr.spln)),]
}
scs.anom.b=data.frame(matrix(NA, nrow = dim(scs.anom)[1], ncol = dim(scs.anom)[2]))
for (i in 1:dim(scs.anom)[1]){
  scs.anom.b[i,23:50]=scs.anom[i,23:50]-scs.yr.spln[which(scs.anom$DOY[i]==rownames(scs.yr.spln)),]
}  

scs.anom.b=rbind(scs.anom.b,test)
# Aggregrate by Year, Yearly anomaly by epu
gbk.yr.anom=aggregate(gbk.anom.b, 
                      by=list(gbk.anom$year),
                      FUN=mean, na.rm=T); 
rownames(gbk.yr.anom)=gbk.yr.anom[,1]; 
gbk.yr.anom[,1]=NULL; 
colnames(gbk.yr.anom)=colnames(gbk.anom)
gom.yr.anom=aggregate(gom.anom.b, 
                      by=list(gom.anom$year),
                      FUN=mean, na.rm=T); 
rownames(gom.yr.anom)=gom.yr.anom[,1]; 
gom.yr.anom[,1]=NULL; 
colnames(gom.yr.anom)=colnames(gom.anom)
mab.yr.anom=aggregate(mab.anom.b, 
                      by=list(mab.anom$year),
                      FUN=mean, na.rm=T); 
rownames(mab.yr.anom)=mab.yr.anom[,1]; 
mab.yr.anom[,1]=NULL; 
colnames(mab.yr.anom)=colnames(mab.anom)
scs.yr.anom=aggregate(scs.anom.b, 
                      by=list(scs.anom$year),
                      FUN=mean, na.rm=T); 
rownames(scs.yr.anom)=scs.yr.anom[,1]; 
scs.yr.anom[,1]=NULL; 
colnames(scs.yr.anom)=colnames(scs.anom)

# Small-Large body copepod abundance anomaly
lgtx=c(25) #column for Calanus finmarchicus
smtx=c(26,24,28,27) 
#Pseudocalanus spp, Centropoges typicus, Centropages hamatus, Temora longicornis

dataTsm=gbk.yr.anom[,smtx]
dataTlg=gbk.yr.anom[,lgtx]
anom.gbk=rowMeans(dataTsm)-(dataTlg)
dataTsm=gom.yr.anom[,smtx]
dataTlg=gom.yr.anom[,lgtx]
anom.gom=rowMeans(dataTsm)-(dataTlg)
dataTsm=mab.yr.anom[,smtx]
dataTlg=mab.yr.anom[,lgtx]
anom.mab=rowMeans(dataTsm)-(dataTlg)
dataTsm=scs.yr.anom[,smtx]
dataTlg=scs.yr.anom[,lgtx]
anom.scs=rowMeans(dataTsm)-(dataTlg)
#```