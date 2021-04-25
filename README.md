# Breath-by-Breath Probability of Obstruction (pobs)
## An automated approach for separating obstructive from central sleep disordered breathing

<img src="https://github.com/aparek/pobs/blob/5b2d2de9b56516cadc62a90b3fbfbedaf86a1447/docs/version1_Artboard%201.png" alt="approach" width="600"/>

Please read detailed instructions below:

#### Minerva software will run only on Windows OS  
#### This software is needed to generate breath tables  
#### For workaround with other OS's please contact @ the email bleow  

**Step 1**: Install Minerva using the .msi installer

**Step 2**: List the .edf files in a text file  
        e.g.,  
        demoTextFile.txt which contains  
        Line1: abc.edf  
        Line2: xyz.edf  

**Step 3**: Call pobs_wrapper_batch using the demoTextFile.txt  
        e.g.,   
        pobs_wrapper_batch('demoTxtfile.txt')  
        
**Step 4**: The code uses 5 signals from routine diagnostic polysomnography  
        Airflow, Thor and Abdo (RIP effort belts), Snore, and SpO2  
        It is upto the user to ensure signal quality is optimal and to exclude bad quality segments  
        POBS does a standard run-of-the-mill quality check and will discard disconnects etc.   
        User should be aware of the signal names and must be edited within the pobs_wrapper_batch function  



Please contact below for a demo of this code.    

------------------------------  
This code is in beta mode and is associated with the publication below. Please cite the publication when using the code. 

Endotyping sleep apnea one breath at a time: An automated approach for separating obstructive from central sleep disordered breathing.  
Parekh, A, Tobert TM, Mooney AM, Ramos-Cejudo J, Osorio RS, Treml M, Herkenrath SD, Randerath WJ, Ayappa I, Rapoport DM. April, 2021 (In Review)

###### Contact:
###### Ankit Parekh ankit.parekh@mssm.edu
