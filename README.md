# Breath-by-Breath Probability of Obstruction (pobs)
## An automated approach for separating obstructive from central sleep disordered breathing

Please read detailed instructions below:

#### Minerva software will run only on Windows OS  
#### This software is needed to generate breath tables  
#### For workaround with other OS's please contact @ the email bleow  

**Step 1**: 
<p>Install Minerva using the .msi installer </p>

**Step 2**: 
<p>List the .edf files in a text file  
        e.g.,  
        demoTextFile.txt which contains  
        Line1: abc.edf  
        Line2: xyz.edf  </p>

**Step 3**: 
<p>Call pobs_wrapper_batch using the demoTextFile.txt  
        e.g.,   
        pobs_wrapper_batch('demoTxtfile.txt')  </p>
        
**Step 4**: 
<p> The code uses 5 signals from routine diagnostic polysomnography Airflow, Thor and Abdo (RIP effort belts), Snore, and SpO2.  
It is upto the user to ensure signal quality is optimal and to exclude bad quality segments.  
        POBS does a standard run-of-the-mill quality check and will discard disconnects etc.     
        User should be aware of the signal names and must be edited within the pobs_wrapper_batch function  </p>



Please contact below for a demo of this code.    

------------------------------  
This code is in beta mode and is associated with the publication below. Please cite the publication when using the code. 

Endotyping sleep apnea one breath at a time: An automated approach for separating obstructive from central sleep disordered breathing.  
Parekh, A, Tobert TM, Mooney AM, Ramos-Cejudo J, Osorio RS, Treml M, Herkenrath SD, Randerath WJ, Ayappa I, Rapoport DM. August, 2021 (Accepted)

###### Contact:
###### Ankit Parekh ankit.parekh@mssm.edu
