######    IDENTIFICATION OF HEAT WAVES DATES AT LARGE SPATIAL DOMAIN      ######
#                                                                             ##
#     Edmondo Di Giuseppe      12 May 2016   ###################################
################################################################################
#
# 1) starts from t?_ECAD_Duration_HeatWave_Cut1_Extended_Marginal.nc files;
# 2) moving averages a 10 termini;
# 3) from daily to hourly time step using linear regression
# 4) identifies the whole relative maximum and their dates---new file for Marco
#------------------------------------------------------------------------------

library(ncdf4)
library(zoo)

### FUNCTIONs HUB         ###
#############################
# Function for relative maximum::
## Vectors with maxima according to 2 time windows (7 and 10 days)
## where a unique maximum is taken:::  
##  x is a zoo time series:::
RelMax<-function(x)  
{
  xx7<-x
  x7<-rep(0,length(x))
  xx10<-x
  x10<-rep(0,length(x))
  
  for(i in 1:length(x))
  {
    #7 days:
    x7[which.max(xx7)]<-max(xx7)
    if(which.max(xx7)<=7){xx7[1:(which.max(xx7)+7)] <- 0}
    if(which.max(xx7) >= (length(xx7)-7)){xx7[(which.max(xx7)-7):length(xx7)] <- 0}
    if(which.max(xx7)>7 & which.max(xx7) < (length(xx7)-7)){xx7[(which.max(xx7)-7):(which.max(xx7)+7)] <-0}
    #10 days:
    x10[which.max(xx10)]<-max(xx10)
    if(which.max(xx10)<=10){xx10[1:(which.max(xx10)+10)] <- 0}
    if(which.max(xx10) >= (length(xx10)-10)){xx10[(which.max(xx10)-10):length(xx10)] <- 0}
    if(which.max(xx10)>10 & which.max(xx10) < (length(xx10)-10)){xx10[(which.max(xx10)-10):(which.max(xx10)+10)] <-0}
  }
  df<-cbind(x,x7,x10)
  return(df)
}  # end function

#------------------------------
#numero di aree:
n.areas<-1         

for (var in c("tn","tx")){
  
  for (i in 1:n.areas){    #ciclo sui files tagliati per aree e periodo
    
    #Extracting data from NetCDF file:
    NC<-nc_open(paste(getwd(),"/Data/",var,"_ECAD_Duration_HeatWave_Cut",i,"_Extended_Marginal.nc",sep=""))
    print(paste("The file has",NC$nvars,"variables"))
    v1 <- NC$var[[1]]
    (varsize <- v1$varsize)
    (ndims   <- v1$ndims)
    (nt <- varsize[ndims]) # Remember timelike dim is always the LAST dimension!
    timeval <- ncvar_get( NC, v1$dim[[ndims]]$name)#, start=1, count=1 )
    timeunit <- v1$dim[[ndims]]$units
    timedate <- as.Date(substr(timeunit,12,nchar(timeunit)))
    
    ## Lettura della variabile v1:
    Marginal <- ncvar_get(NC,v1)
    nc_close(NC)
    
    summary(Marginal)
    
    # Marginal.ts<-ts(Marginal,start=c(1951,1),frequency=365)  #seq(timedate,by="day",length.out=nt))
    # plot(Marginal.ts,col="red")
    # require(raster)
    # appo<-movingFun(Marginal.ts,n=10,fun=mean)
    
    MargZoo<-zoo(Marginal,seq(timedate,by="day",length.out=nt))
    # x<-rollmean(MargZoo,10)
    # plot(x) 
    # 
     
    
    # Apply function for Relative Maxima (and 3 threshold for small extended HW
    ## +Table):
    #---------------------
    final<-RelMax(MargZoo)
    plot(final,type="l")
    
    ## thresholds for cutting:
    #-------------------------
    x7tab<-with(final,hist(x7, breaks=c(0,50,100,300,500,max(x7)), plot = FALSE))
    x10tab<-with(final,hist(x10, breaks=c(0,50,100,300,500,max(x10)), plot = FALSE))
    label0<-cbind(x7tab$breaks,c(x7tab$breaks[-1],NA))
    label<-paste(label0[1:5,1],"-",label0[1:5,2],sep="")
    tab<-rbind(x7tab$counts,x10tab$counts)
    rownames(tab)<-c("7daysCut","10daysCut")
    colnames(tab)<-label
    
    #Only May-Sept:
    Xdates<-time(final)
    Xmonths<-months.Date(Xdates,abbreviate = T)
    Xindex<-Xmonths=="Mag"| Xmonths=="Giu" | Xmonths=="Lug" | Xmonths=="Ago" | Xmonths=="Set"  
    
    finalMaySept<-window(final,index. = Xdates[Xindex])
    plot(finalMaySept)
    abline(v=as.numeric(time(finalMaySept[finalMaySept$x10>=1000,])),col="red")

    summary(finalMaySept)
    
    x7tab<-with(finalMaySept,hist(x7, breaks=c(0,50,100,300,500,max(x7)), plot = FALSE))
    x10tab<-with(finalMaySept,hist(x10, breaks=c(0,50,100,300,500,max(x10)), plot = FALSE))
    label0<-cbind(x7tab$breaks,c(x7tab$breaks[-1],NA))
    label<-paste(label0[1:5,1],"-",label0[1:5,2],sep="")
    tabMaySept<-rbind(x7tab$counts,x10tab$counts)
    rownames(tabMaySept)<-c("7daysCut","10daysCut")
    colnames(tabMaySept)<-label
    
    assign(paste(var,"_Area",i,"_final",sep=""),value = final)
    assign(paste(var,"_Area",i,"_tab",sep=""),tab)
    write.table(cbind(rownames(as.matrix(final)),as.matrix(final)),
                file = paste("Output/",var,"_Area",i,"_final.txt",sep=""),
                row.names = FALSE,sep=",")
    
    ## CREATE NETCDF OF COMPLETE TABLE DATA ####
    # 
    # # Create dimensions lon, lat, level and time
    # dim_lon <- ncdim_def( "longitude", "degrees_east", seq(9.5, 14, by=0.1), create_dimvar=TRUE)
    # dim_lat <- ncdim_def( "latitude", "degrees_north", seq(41,45,by=0.1), create_dimvar=TRUE)
    dim_time<- ncdim_def( "time", units="days since 1951-01-01",vals=1:nrow(final), unlim=TRUE)  #units="30 minutes",
    #mv <- NA 
    # 
    # # Create a new variable "cells", create netcdf file, put updated
    # # contents on it and close file    
    var1_out <- ncvar_def("cells","number",  dim=list(dim_time), prec="integer",longname="Time series of #Cells hit by HW")
    var2_out <- ncvar_def("cellsX7","number",  dim=list(dim_time), prec="integer",longname="Time series of #Cells hit by HW assuming (-7,+7) days of separation")
    var3_out <- ncvar_def("cellsX10","number",  dim=list(dim_time), prec="integer",longname="Time series of #Cells hit by HW assuming (-10,+10) days of separation")
    ncid_out<- nc_create(paste(var,"_Area",i,"_HW_spatial_extension.nc",sep=""), vars=list(var1_out,var2_out,var3_out))
    ncvar_put(ncid_out, varid=var1_out, vals=final$x, start=c(1), count=c(nrow(final)))                                                                
    ncvar_put(ncid_out, varid=var2_out, vals=final$x7, start=c(1), count=c(nrow(final)))                                                             
    ncvar_put(ncid_out, varid=var3_out, vals=final$x10, start=c(1), count=c(nrow(final)))  
    nc_close(ncid_out)
    ## 
    
    #Save same objects for May-Sept::
    assign(paste(var,"_Area",i,"_finalMaySept",sep=""),value = finalMaySept)
    assign(paste(var,"_Area",i,"_tabMaySept",sep=""),tabMaySept)
    write.table(cbind(rownames(as.matrix(finalMaySept)),as.matrix(finalMaySept)),
                file = paste("Output/",var,"_Area",i,"_finalMaySept.txt",sep=""),
                row.names = FALSE,sep=",")
    
   }
}


# Save some objects for report::
save(list=c("tx_Area1_final","tx_Area1_finalMaySept","tx_Area1_tab","tx_Area1_tabMaySept",
            "tn_Area1_final","tn_Area1_finalMaySept","tn_Area1_tab","tn_Area1_tabMaySept"),
          file="HW_SpatialExtension.RData")


# Prove funzione:

# xlag1<-diff(x,1)
# tutti<-as.matrix(cbind(x,xlag1,xlag1/24))
# #hourly sequence:
# y<-rep(NA,24)
# for (i in 2:(length(x)-1)) {   
#   hours24<-cumsum(c(tutti[i,1],rep(tutti[(i+1),3],each=23)))
#   y<-c(y,hours24)
# }
# y<-c(y,rep(tutti[i,1],24))
# 
# h<-seq.POSIXt(from = as.POSIXct("1951-01-01 00:00:00", "%Y-%m-%d %H:%M:%S", tz = ""), by = "hour",length.out=nt*24)
# 
# y.zoo<-zoo(y,h)
# time=time(y.zoo)
# 
# library(pspline)
# # prova<-sm.spline(time, y.zoo)
# timecut=time[1:300]
# y.zoocut=y.zoo[1:300]
# d1<-predict(sm.spline(timecut, y.zoocut), timecut, 1)
# # d2<-predict(sm.spline(time, x), time, 2)
# appo<-x[d1>-0.5 & d1<0.5 & d2<(-0.5)]
# plot(appo)
# abline(v=as.vector(time(appo)),col="lightgrey")
# 
# require(raster)
# appo<-movingFun(y.zoo,n=10,fun=mean)
# 
# dx<-D(expression(x),"x")
# d1<-eval(dx,list(x=appo))
# plot(attr(d1,"gradient"))
# 
# require(numDeriv)
# funct1<-function(x){x=x}
# curve(funct1,from=0,to=5)
# d1<-grad(func=funct1,x=appo[1:200],method="simple")
