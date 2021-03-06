/*==========================================================
 * mexmaxflow.cpp - Configure maxflow for matlab
 *
 *
 *========================================================*/
/* $Revision: 1.5.4.4 $ */

#include <stdio.h>
#include "graph.h"
#include <iostream>
#include "mex.h"

using namespace std;

void mexFunction(
		 int          nlhs,
		 mxArray      *plhs[],
		 int          nrhs,
		 const mxArray *prhs[]
		 )
{
  /* Check for proper number of arguments */
  if (nrhs != 4) {
    mexErrMsgIdAndTxt("MATLAB:mexmaxflow:nargin", 
            "MEXCPP requires four input arguments.");
  } else if (nlhs != 1 && nlhs != 2) {
    mexErrMsgIdAndTxt("MATLAB:mexmaxflow:nargout",
            "MEXCPP requires one output argument.");
  }

  //parse out arguments

  double *backWeights = (double *) mxGetPr(prhs[0]);
  double *foreWeights = (double *) mxGetPr(prhs[1]);
  double *smoothIndices = (double *) mxGetPr(prhs[2]);
  double *smoothWeights = (double *) mxGetPr(prhs[3]);
  size_t numNodes = mxGetNumberOfElements(prhs[0]);
  size_t numDirections = mxGetN(prhs[2]);

  //Error checking
  if (numNodes != mxGetNumberOfElements(prhs[1])) mexErrMsgIdAndTxt("MATLAB:mexmaxflow:argin", "Weight arrays must be same length");
  if (numNodes != mxGetM(prhs[2])) mexErrMsgIdAndTxt("MATLAB:mexmaxflow:argin", "Number of rows for edge matrix does not match number of nodes");
  if (mxGetN(prhs[2]) != mxGetN(prhs[3]) || mxGetM(prhs[2]) != mxGetM(prhs[3])) mexErrMsgIdAndTxt("MATLAB:mexmaxflow:argin", "Edge weights matrix does not match edge indices matrix");

  //Create and fill graph
  typedef Graph<double, double, double> GraphType;
  GraphType *g = new GraphType(((int)numNodes),((int)(numNodes*numDirections)));
  g->add_node(((int)numNodes));

  //Background is source, foreground is sink
  for (size_t i=0; i<numNodes; i++)
  {
	g->add_tweights(i, backWeights[i], foreWeights[i]);
	for (size_t j=0; j<numDirections; j++)
	{
        //mexPrintf("Value1 = %g\n", smoothIndices[numNodes*j + i]);
		int edgeIndex = (int)(smoothIndices[numNodes*j + i]-1);
		double edgeWeight = smoothWeights[numNodes*j + i];
		if (edgeIndex < 0) continue;
        else if (edgeIndex >= numNodes) mexErrMsgIdAndTxt("MATLAB:mexmaxflow:argin", "Illegal edge index");
        else if (edgeIndex >= i) continue;
		g->add_edge(edgeIndex, i, edgeWeight, edgeWeight);
	}
  }

  //Calc flow
  double energy = g->maxflow();

  plhs[0] = mxCreateNumericMatrix(numNodes, 1, mxDOUBLE_CLASS, mxREAL);	
  double* arrPtr = mxGetPr(plhs[0]);
  //Set alpha
  for (size_t i=0; i<numNodes; i++)
  {
	  arrPtr[i] = g->what_segment(i) == GraphType::SINK;
  }
  plhs[1] = mxCreateDoubleScalar(energy);
  
  delete g;

  return;
}