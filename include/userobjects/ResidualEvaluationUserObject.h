//* This file is part of the MOOSE framework
//* https://www.mooseframework.org
//*
//* All rights reserved, see COPYRIGHT for full restrictions
//* https://github.com/idaholab/moose/blob/master/COPYRIGHT
//*
//* Licensed under LGPL 2.1, please see LICENSE for details
//* https://www.gnu.org/licenses/lgpl-2.1.html

/*
Recompute Residual after System Solve
*/

#pragma once

#include "GeneralUserObject.h"

class ResidualEvaluationUserObject : public GeneralUserObject
{
public:
  static InputParameters validParams();
  ResidualEvaluationUserObject(const InputParameters & parameters);
  virtual void initialize() override {}
  virtual void execute() override;
  virtual void finalize() override {}

protected:
  std::set<TagID> _vector_tags;
};
