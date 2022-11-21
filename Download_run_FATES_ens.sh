#!/bin/bash 

module load NCO/4.7.9-intel-2018b

#Scrip to clone, build, run and analyze CLM-FATES ensamble simulation.
#Based on Rosie Fisher's jupyter notebook: https://github.com/adrifoster/fates-global-cal/blob/main/jupyter_ppe_scripts/albedo_ensemble_script.ipynb

dosetup=0 #do we want to create parameters files and so on?
dosubmit=0 #do we do the submission stage, or just the analysis?
forcenewcase=0 #do we scurb all the old cases and start again?
doanalysis=1 #do we want to plot the outputs? 

echo "setup, submit, analysis:", $dosetup, $dosubmit, $doanalysis 


doSP=1 #use SP or nocomp FATES configuration

USER="kjetisaa"
project='nn8057k' #nn8057k: EMERALD, nn2806k: METOS, nn9188k: CICERO
machine='fram'
setCPUs=0 #For setting number of CPUs. Now hardcoded to 128
pmode=1 #mode of varying the parameters. OAAT. 

# what is your clone of the ctsm repo called? (or you want it to be called?) 
ctsmrepo="Nov2022_CLMFATES"
#what do you want the directory with the ensemble cases in to be called?
ens_directory='FATES_CAL_ENS_PMODE'$pmode
#what do you want the case names to begin with?
caseroot=$ens_directory'_case_'

#path to scratch (or where the model is built.)
scratch="/cluster/work/users/$USER/"
#where are we now?
startdr=$(pwd)
# aka where do you want the code and scripts to live?
workpath="/cluster/work/users/$USER/" #previously: 'gitpath'
# some more derived path names to simplify latter scripts
scriptsdir=$workpath$ctsmrepo/cime/scripts/
#echo $scriptsdir
#ls $workpath


#NB: these lists are duplicated in the plotting script. Remember to change both places!!!
if [ $pmode -eq 1 ]
then 
    parameter_list=('fates_rad_leaf_clumping_index' 'fates_rad_leaf_xl' 
                'fates_rad_leaf_rhovis'  'fates_rad_stem_rhovis' 
                'fates_rad_leaf_tauvis' 'fates_rad_stem_tauvis' 
               'fates_vai_top_bin_width' 'fates_vai_width_increase_factor')
    parameter_label=('clumping_index' 'leaf_xl' 
                'leaf_rhovis' 'stem_rhovis' 
                'leaf_tauvis' 'stem_tauvis' 
               'top_bin_width' 'width_increase_factor')
    nparams=8    
    #how many members are in the ensemble?
    #sp=1 #are we using SP mode?
    ncases=$((nparams*2)) #number of cases, excluding reference case (will use index zero for this)
    #ncases=2
    min_delta=( 0.5   0.01 0.75 0.75 0.75 0.75 0.25 1.1 )
    max_delta=( $(echo "1.0/0.85" | bc -l) 1.4 1.25 1.25 1.25 1.25 0.5 1.25 )

# ensemble 2 is to look at a range of absolute values of xl
elif [ $pmode -eq 2 ] 
then
    pvalue=(-0.99 -0.75 -0.5 -0.25 0 0.25 0.5 0.75 0.99)
    ncases = 8 #(this is zero indexed)
    parameter_list=('fates_rad_leaf_xl')
    parameter_label=['leaf_xl']

elif [ $pmode -eq 3 ] 
then
    parameter_list=('fates_vai_top_bin_width' 'fates_vai_width_increase_factor')
    parameter_label=('top_bin_width' 'width_increase_factor')    
    pvalue1=(1 1 1 1
             0.5  0.5 0.5 0.5
             0.2 0.2 0.2 0.2
             0.1 0.1 0.1 0.1
             0.05 0.05 0.05 0.05)
    pvalue2=(1.0 1.1 1.2 1.3
             1.0 1.1 1.2 1.3
             1.0 1.1 1.2 1.3
             1.0 1.1 1.2 1.3
             1.0 1.1 1.2 1.3)
    ncases=19 # not sure why this is n-1 but it is.        
    parameter_label=('bin_wid' 'inc_f')
fi


if [ $doSP -eq 1 ] 
then
    defcase='SPdefault_nov'
    paramfiledefault='fates_params_default.nc'
    compset='2000_DATM%GSWP3v1_CLM51%FATES_SICE_SOCN_SROF_SGLC_SWAV_SESP'
    nl_casesetup_string1='use_fates_sp = true'
    echo 'SP simulation'
elif [ $doSP -eq 2 ] 
then
    defcase='NOCOMPdefault_nov'
    compset='2000_DATM%GSWP3v1_CLM51%FATES_SICE_SOCN_SROF_SGLC_SWAV_SESP'
    paramfiledefault='fates_params_default.nc'
    nl_casesetup_string1='use_fates_sp = false'
#TODO: need better solution here (inlcuding multiple lines)
#Can use this syntax: echo -e "this is a new line \nthis is another new line" >> file.txt
    echo 'NOCOMP simulation'
else
    defcase='CLM_SP_default_nov'
    compset='2000_DATM%GSWP3v1_CLM51%SP_SICE_SOCN_SROF_SGLC_SWAV_SESP'
    paramfiledefault='fates_params_default.nc'
    echo 'CLM SP (no FATES)'
fi

#path to results (history) 
#results_dir="/cluster/work/users/$USER/archive/$defcase/lnd/hist/"
results_dir="/cluster/work/users/$USER/"

#set up the parameter file paths even if not in 'setup' mode
paramsdir=$scriptsdir/$ens_directory/parameter_files/
defparamdir=$workpath/$ctsmrepo/src/fates/parameter_files/

#ls -l $defparamdir
#echo $defparamdir

#case charecteristics
resolution='f45_f45_mg37'



#Download code and checkout externals
if [ $dosetup -eq 1 ] 
then
    cd $workpath

    pwd
    #go to repo, or checkout code
    if [[ -d "$ctsmrepo" ]] 
    then
        cd $ctsmrepo
        echo "Already have ctsm repo"
    else
        echo "Cloning ctsm"
        #clone CTSM code if you didn't to this already. 
        git clone https://github.com/escomp/ctsm $ctsmrepo
        cd $ctsmrepo
        ./manage_externals/checkout_externals
        cd src
    fi
fi


#Make default FATES case
if [[ $dosetup -eq 1 ]] 
then
    cd $scriptsdir
    if [[ -d "$defcase" ]] 
    then    
        echo "$defcase exists on your filesystem."
    else
        echo "making defcase.",$defcase
        ./create_newcase --case $defcase --compset $compset --res $resolution  --run-unsupported --project $project --machine fram
        cd $defcase

        #XML changes
        echo 'updating settings'
        ./xmlchange CONTINUE_RUN=FALSE
        ./xmlchange --id STOP_N --val 3
        ./xmlchange --id STOP_OPTION --val nyears
        ./xmlchange --id CLM_FORCE_COLDSTART --val on
        ./xmlchange --subgroup case.run JOB_WALLCLOCK_TIME=20:00:00
        

        if [[ $setCPUs -eq 1 ]]
        then 
            echo 'setting #CPUs to 128'    
            ./xmlchange NTASKS_ATM=128
            ./xmlchange NTASKS_OCN=128
            ./xmlchange NTASKS_LND=128
            ./xmlchange NTASKS_ICE=128
            ./xmlchange NTASKS_ROF=128
            ./xmlchange NTASKS_GLC=128
        fi
        echo 'done with xmlchanges'        
        
        ./case.setup

        echo $nl_casesetup_string1 >> user_nl_clm
        
        ./case.build
    fi
fi
echo "Currently in" $(pwd)


#--Make ensables---
mkdir $scriptsdir$ens_directory
mkdir $scriptsdir$ens_directory/parameter_files

if [[ $dosetup -eq 1 ]]
then
    cd $scriptsdir

    counter1=0 #include a default zero case. 
    while [ $counter1 -le $ncases ]
    do
        newcase=$caseroot$counter1 #name of ensemble membr case. 
        echo $newcase
        if [ -d $ens_directory/$newcase ]
        then
            echo ' new case already exists',$ens_directory/$newcase
            if [ $forcenewcase -eq 1 ]
            then
            echo 'force making case', $ens_directory/$newcase
            rm -rf $ens_directory/$newcase
            rm -rf $workpath/ctsm/$newcase #Something like this is needed, but not sure about the right paths            
            ./create_clone --clone $defcase --case $ens_directory/$newcase  --keepexe;
#            cd $ens_directory/$newcase
#            echo 'case setup', $ens_directory/$newcase
#            ./case.setup;
#            cd ../../ 
            fi    
        else
            echo 'making new case', $ens_directory/$newcase
            ./create_clone --clone $defcase --case $ens_directory/$newcase  --keepexe;
#            cd $ens_directory/$newcase
#            echo 'case setup', $ens_directory/$newcase
#            ./case.setup;
#            cd ../../ 
        fi
        ((counter1++))
    done

fi

#SETUP
if [[ $dosetup -eq 1 ]] 
then  
    cd $scriptsdir/$defcase    
    #Make default user_nl_clm    
    if [ -e 'user_nl_clm_default' ] 
    then
        rm user_nl_clm_default
    fi
    cp user_nl_clm user_nl_clm_default
    #ls -l user_nl_clm_default

    #Write configuration and dummy parameter filename into defualt user_nl_clm file
    if  [[ $doSP -eq 1 ]]
    then
        #echo $nl_casesetup_string1 >> user_nl_clm_default
        #No need for this, since defcase already has this!
        tail user_nl_clm_default
        echo ''        
    fi
    echo 'fates_paramfile = "nullparameterfile"' >> user_nl_clm_default #writing dummy to default namelist

    # copy this 'fresh' default file into the ensemble directory. 
    cp user_nl_clm_default  $scriptsdir$ens_directory/user_nl_clm_default
    #tail  $scriptsdir$ens_directory/user_nl_clm_default
    #echo ''

    cd $scriptsdir  
fi
 
#SETUP: Create and modify ensemble of parameter files
if [[ $dosetup -eq 1 ]] 
then  
    #Make default parameter file
    newfilenc=$defparamdir/fates_params_default.nc
    template_cdl=$defparamdir/fates_params_default.cdl
    if [ -e $newfilenc ] 
    then
        rm $newfilenc
    fi   
    ncgen $template_cdl -o $newfilenc    
    filename_template=$paramsdir$paramfiledefault
    cp $newfilenc $filename_template

    #Create ensamble of param files
    fatesparamfile=fates_params_
    echo $fatesparamfile    
    for (( i=0; i<=$ncases; i++ )) #keep 0 as the default
    do        
        filename_out=$paramsdir$fatesparamfile$i.nc 
        echo 'filename_out=' $filename_out
        cp $filename_template $filename_out
    done
    
    #Modify ensable of param files
    if [[ $pmode -eq 1 ]] #multiplicative peturbation
    then 
        for (( j=1; j<=nparams; j++ ))   #param index     
        do  
            (( k=j*2-1 )) #file number 1 3 ... (0 is for default simulation)
            (( i=j-1 )) #index in param list (starting with 0)
            filename_out=$paramsdir$fatesparamfile$k.nc
            ncap2 -O -s "${parameter_list[i]}=${parameter_list[i]}*${min_delta[i]};" $filename_out $filename_out
            echo "Modifying $fatesparamfile$k.nc by ${parameter_list[i]}*${min_delta[i]}"

            (( k=j*2 )) #file number 2 4 ... (0 is for default simulation)
            filename_out=$paramsdir$fatesparamfile$k.nc
            ncap2 -O -s "${parameter_list[i]}=${parameter_list[i]}*${max_delta[i]};" $filename_out $filename_out
            echo "Modifying $fatesparamfile$k.nc by ${parameter_list[i]}*${max_delta[i]}"
        done
    elif [[ $pmode -eq 2 ]] #TODO
    then
        echo ' '
        #var[:] = var[:]*0+delta
    elif [[ $pmode -eq 3 ]] #TODO
    then
        echo ' '
        #var[:] = var[:]*0+delta
    fi    
fi

#SETUP: Point each ensemble script to a different parameter file
if [[ $dosetup -eq 1 ]] 
then  
    root=$scriptsdir$ens_directory
    for (( i=0; i<=ncases; i++ ))
    do
        pftfilename=$paramsdir$fatesparamfile$i'.nc'    
        unlfile=$root'/'$caseroot$i'/user_nl_clm'
        defunl=$scriptsdir$ens_directory'/user_nl_clm_default' 
        cp $defunl $unlfile
        sed -i "s+nullparameterfile+$pftfilename+g" $unlfile  
        ls -l   $unlfile
    done
    echo "Checking last namelist file"
    tail -n 10 $unlfile 
fi

#SETUP: Check parameter files were correctly modifed
#(TODO)


#Submit job
if [[ $dosubmit -eq 1 ]] 
then

    if [[ $submitdef -eq 1 ]] #Currently not defined, so this part will be skiped
    then
        cd $scriptsdir/$defcase
        ./case.submit
        echo 'done submitting'  
        cd $startdr  

        #Check job (TODO)
        rund="$scratch/ctsm/$defcase/run/"
        echo $rund
        #ls -lrt $rund   
    fi

    #vs=range(2,4)
    cd $scriptsdir'/'$ens_directory
    #for i in vs:
    for (( i=0; i<=ncases; i++ ))
    do
        newcase=$caseroot$i        
        #if(os.path.isdir(newcase)): 
        if [ -d $newcase ]
        then 
            cd $newcase
            echo 'submitting job ' $newcase
            #os.system('./xmlchange BUILD_COMPLETE=TRUE');
            ./case.submit
            cd $scriptsdir'/'$ens_directory
        else
            echo 'no case' $newcase
        fi
    done
    echo 'done submitting'
fi

echo 'Currently in ' $(pwd)

#Analyse output 
if [[ $doanalysis -eq 1 ]] 
then
    # Set up job environment
    module purge
     
    set -o errexit # exit on any error
    set -o nounset # treat unset variables as error

    # Load modules
    module load Python/3.9.6-GCCcore-11.2.0

    # Set the ${PS1} (needed in the source of the virtual environment for some Python versions)
    export PS1=\$

    # activate the virtual environment
    source /cluster/home/kjetisaa/Full_FATES_Workflow/Def_pythonenv/bin/activate

    # execute ensable plotting script
    echo 'Calling Plot_Ens_diff.py with following arguments:'
    echo $results_dir $caseroot $ncases $pmode 
    python Plot_Ens_diff.py $results_dir $caseroot $ncases $pmode 

fi