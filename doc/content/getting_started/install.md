# Install farmsquakeworx

farmsquakeworx is a perfect example of integration of multiple open source projects.

- farmsquakeworx is built upon [MOOSE](https://mooseframework.inl.gov/), an object oriented parallel FEM framework.
- MOOSE is built upon [libMesh](http://libmesh.github.io/), a C++ FEM library, to utilize its FEM basics.
- Both MOOSE and libMesh rely on many other tools, such as [PETSc](https://www.mcs.anl.gov/petsc/).

Therefore, it can be complicated to get farmsquakeworx to work. Fortunately, the installation process
has been thought through and thoroughly tested. The installation process can be summarized in the following steps,
each of which should only take a handful of commands.

!include getting_started/dcc.md

### Step 1: Install dependencies style=line-height:150%;

First, follow [these instructions](getting_started/conda.md) to install environment packages for MOOSE and farmsquakeworx.

### Step 2: Clone farmsquakeworx style=line-height:150%;

Next, clone farmsquakeworx to your local projects directory:

```bash
mkdir ~/projects
cd ~/projects
git clone https://github.com/chunhuizhao478/farmsquakeworx.git 
cd farmsquakeworx
git checkout master
```

These commands should download a copy of farmsquakeworx and a copy of MOOSE (as a submodule) to your local projects directory.
The moose repository needs to be downloaded separately and place alongside with the farmsworx folder.

### Step 3: Compile Farmsquakeworx style=line-height:150%;

Next, you can compile Farmsquakeworx using

```bash
make -j N
```

where `N` is the number of processors you want to use to compile Farmsquakeworx in parallel.

> +\[Optional\]+ To make sure Farmsquakeworx is working properly, run the regression tests:
>
> ```bash
> ./run_tests -j N
> ```
