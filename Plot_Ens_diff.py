#!/usr/bin/env python
import os
import netCDF4 as nc4
import sys
import shutil
import numpy as np
import warnings
warnings.filterwarnings('ignore')
import xarray as xr
from matplotlib import pyplot as plt
#import datetime

output_dir = sys.argv[1]
caseroot = sys.argv[2]
ncases = int(sys.argv[3])
pmode = int(sys.argv[4])

#NB: Currently, this section is duplicated in both scripts. Not very neat, but ok solution for now. 
if(pmode == 1):
    parameter_list=['fates_rad_leaf_clumping_index','fates_rad_leaf_xl',
                'fates_rad_leaf_rhovis','fates_rad_stem_rhovis',
                'fates_rad_leaf_tauvis','fates_rad_stem_tauvis' ,
               'fates_vai_top_bin_width','fates_vai_width_increase_factor']
    parameter_label=['clumping_index','leaf_xl',
                'leaf_rhovis','stem_rhovis',
                'leaf_tauvis','stem_tauvis' ,
               'top_bin_width','width_increase_factor']
    min_delta=[0.5,   0.01,0.75, 0.75, 0.75,0.75, 0.25, 1.1]
    max_delta=[1/0.85,1.4 ,1.25, 1.25, 1.25,1.25, 0.5, 1.25]   
    
# ensemble 2 is to look at a range of absolute values of xl
if(pmode == 2):
    pvalue=[-0.99, -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 0.99]
    parameter_list=['fates_rad_leaf_xl']    
    parameter_label=['leaf_xl']
if(pmode == 3):
    parameter_list='fates_vai_top_bin_width','fates_vai_width_increase_factor'
    parameter_label=['top_bin_width','width_increase_factor']
    pvalue1=[1, 1, 1, 1, 0.5, 0.5, 0.5, 0.5, 0.2, 0.2, 0.2, 0.2,
             0.1, 0.1, 0.1, 0.1, 0.05, 0.05, 0.05, 0.05]
    pvalue2=[1.0, 1.1, 1.2, 1.3, 1.0, 1.1, 1.2, 1.3, 1.0, 1.1, 1.2, 1.3,
             1.0, 1.1, 1.2, 1.3, 1.0, 1.1, 1.2, 1.3]     
    parameter_label=['bin_wid', 'inc_f']

debug=1 
hstring = '.clm2.h0.'
convs = [3600*24*365, 1, 1, 1, 1, 1]
ychoose = '2002'
mchooses = ['-02', '-07'] 
#delta=1
#rel=1
#vlim=0.25
vlims=[0.25, 10, 25, 25, 10, 10] 

vars=['FATES_GPP','FSR','SABV','SABG','EFLX_LH_TOT','FSH','lat','lon','time']

missing=range(0,ncases+1)
missing=np.multiply(missing,0)

def make_directory(fileroot):   
    if(os.path.isdir(fileroot)):
        print('dir exists:'+fileroot)
    else:
        os.mkdir(fileroot)
        print('made: '+fileroot)

def make_diff_figure(dsc,v,conv,ncases,pmode,vlim,parameter_label):       
    if(pmode == 1):
        fig = plt.figure(figsize=(22, 7))
    if(pmode == 2):
        fig = plt.figure(figsize=(17, 7))
    if(pmode == 3):
        fig = plt.figure(figsize=(12, 10))
    fig.subplots_adjust(hspace=0.2, wspace=0.3)    
    if(pmode == 3):
        nrow=5
    else:
        nrow=2
    ncol=(ncases) // nrow #Not including default simulation (index zero)
    count=1
    var_0=dsc[vars[v]].isel(ens=0)
    defm=np.multiply(np.mean(var_0,0),conv)
    vs=range(1,ncases+1)
    for i in vs:
        index=((count+1) % nrow)*ncol + ((count+1) // nrow)
        p=((count+1) // nrow)-1
        if(pmode == 3):index = i+1
        #if pmode == 2:var_i=dsc[vars[v]].isel(ens=i)
        #if pmode == 3:var_i=dsc[vars[v]].isel(ens=i) 
        var_i=dsc[vars[v]].isel(ens=i) #Moved out of "if pmode= 2 or 3"
        mod=np.multiply(np.mean(var_i,0),conv)
        delt=mod-defm
        if(pmode == 1):
            if((count+1) % 2==0):
                ex=' x'+str(min_delta[p])
            else:
                ex=' x'+str(max_delta[p])
        if(pmode == 2):
            ex = ' x'+str(pvalue[i])
            print('pmode=2 not ready')
        if(pmode == 3):
            ex0 = ' ='+str(pvalue1[i])
            ex1 = ' ='+str(pvalue2[i])
            print('pmode=3 not ready')
        ax = fig.add_subplot(nrow, ncol, index)
        if(missing[i]==1):
            print('missing plot',i)            
        else:         
            plt1=delt.plot(cmap='RdYlBu',vmin=-vlim,vmax=vlim)                  
            ax.get_xaxis().set_visible(False)
            ax.get_yaxis().set_visible(False)
        if pmode == 1 : ax.set_title(str(parameter_label[(((count+1) // 2))-1]+ex))        
        if pmode == 2 : ax.set_title(str(parameter_label[0]+ex))
        if pmode == 3 : ax.set_title(parameter_label[0]+str(ex0)+' '+parameter_label[1]+str(ex1))
        fig.suptitle(vars[v]+', '+ychoose+mchoose, fontsize=16)
        count=count+1
        fig.canvas.draw()
        figname = figpath+vars[v]+'.png'
    print(figname)
    plt.savefig(figname)


for m in range(0,2):
    mchoose=mchooses[m]
    
    #figpath = ('Ens_pmode'+str(pmode)+'_figures/')
    figpath = ('Figures_Ens_Pmode'+str(pmode)+'_'+ychoose+mchoose+'/')
    make_directory(figpath)

    vs=range(0,ncases+1)
    print(vs)
    for i in vs: 
            run=caseroot+str(i) 
            #os.listdir(output_dir + '/archive')
            arc = output_dir + 'archive/' + run + '/lnd/hist/' 
            hpath = arc
            tfile = run+hstring+ychoose+mchoose+'.nc' 
            if(os.path.isdir(hpath)): 
                if(os.path.isfile(hpath+tfile)): 
                    if debug == 1 :print('file in archive')
                    missing[i]=0
                else:
                    if debug == 1 :print('file not in archive',hpath+tfile)
            else:
                if(debug == 1):print('no archive')
                hpath = output_dir + run + '/run/'            
                if(os.path.isdir(hpath)): 
                    print('is rundir',hpath)                
                    if(os.path.isfile(hpath+tfile)):
                        if debug == 1 :print('file in  rundir')
                        missing[i]=0
                    else:
                        print('no file in  rundir',hpath+tfile)
                        missing[i]=1
                else:
                    print('no  rundir',hpath)
                    missing[i]=1 #KSA added
            
            if(missing[i]==0):
                allvars=list(xr.open_dataset(hpath+tfile, decode_times=False).variables)
                dropvars=list(set(allvars) - set(vars)) #thanks to Ben for figuring this part out :) 
                print('file'+str(i)+' ='+hpath+tfile)
                tmp=xr.open_mfdataset(hpath+tfile, decode_times=False, drop_variables=dropvars) 
                    
            if i==0:
                #del dsc
                dsc = tmp           
            else:
                dsc=xr.concat([dsc,tmp],'ens')
    #print(missing)

    outfile=figpath+'/dataout.nc' 
    dsc.to_netcdf(outfile)
    os.listdir(figpath)
    

    for v in range(0,len(vars)-3): #exclude lat, lon, time
        make_diff_figure(dsc,v,convs[v],ncases,pmode,vlims[v],parameter_label)