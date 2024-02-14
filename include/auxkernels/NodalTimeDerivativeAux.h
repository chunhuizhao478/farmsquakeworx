/*
AuxKernel of Passing Variable Time Derivative 
*/

#pragma once

#include "AuxKernel.h"

class NodalTimeDerivativeAux : public AuxKernel
{
    public:

    static InputParameters validParams();
    NodalTimeDerivativeAux(const InputParameters & parameters);

    protected:

    virtual Real computeValue() override;

    const VariableValue & _coupled_val;

};



