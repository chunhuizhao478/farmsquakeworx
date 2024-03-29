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

#include "ResidualEvaluationUserObject.h"

registerMooseObject("farmsquakeworxApp", ResidualEvaluationUserObject);

InputParameters
ResidualEvaluationUserObject::validParams()
{
  // Get the input parameters from the parent class
  InputParameters params = GeneralUserObject::validParams();

  // Add required parameters
  params.addRequiredParam<std::vector<TagName>>("vector_tag", "Tag Name of the residual");
  params.addClassDescription("Re-evaluate the residual with the lateset solution");

  return params;
}

ResidualEvaluationUserObject::ResidualEvaluationUserObject(const InputParameters & parameters)
  : GeneralUserObject(parameters)
{
  auto & vector_tag_names = getParam<std::vector<TagName>>("vector_tag");
  for (auto & vector_tag_name : vector_tag_names)
  {
    const TagID vector_tag_id = _fe_problem.getVectorTagID(vector_tag_name);
    _vector_tags.insert(vector_tag_id);
  }
}

void
ResidualEvaluationUserObject::execute()
{
  _fe_problem.computeResidualTags(_vector_tags);
}
