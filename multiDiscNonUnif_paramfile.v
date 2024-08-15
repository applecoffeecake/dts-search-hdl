// MIT License
//
// Copyright (c) 2024 Mohannad Shehadeh
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

parameter M = 19; // max mark 
parameter k = 3; // num marks per block
parameter SKIM = 25; // uniform prng source width 
parameter SIZE = 50; // lfsr size 
parameter [SIZE-1:0] FEEDBACK = 50'h2000000000EE2 ; // lfsr prim poly
parameter [SIZE-1:0] SEED = 50'h1c5cb13ca1ce0 ; // lfsr seed 
parameter M_WIDTH = 5; // num bits to represent M 
parameter k_iWIDTH = 2; // num bits to represent k choices 
// boundaries of bins to produce k different non-uniform distributions 
parameter [SKIM*M*k - 1 : 0] BINBOUND =
{25'h574019,
25'h8089fb,
25'hb25902,
25'he9e3e2,
25'h1232467,
25'h159b16e,
25'h189bd3c,
25'h1b0db0d,
25'h1ce4b24,
25'h1e2c59e,
25'h1eff0b6,
25'h1f7c47b,
25'h1fc116e,
25'h1fe4094,
25'h1ff4713,
25'h1ffb8fc,
25'h1ffe6ad,
25'h1fff79e,
25'h1ffffff,
25'h4174a,
25'h81c20,
25'hf20a5,
25'h1a9455,
25'h2c0b49,
25'h44ef5c,
25'h66167a,
25'h8f5ab6,
25'hbf5bac,
25'hf38b36,
25'h1288ff0,
25'h15ae6a6,
25'h1879121,
25'h1ac9ae8,
25'h1c94eca,
25'h1de1847,
25'h1ec29ef,
25'h1f51004,
25'h1ffffff,
25'he,
25'h4e,
25'h17f,
25'h684,
25'h1960,
25'h586a,
25'h113e8,
25'h30415,
25'h7946c,
25'h11244b,
25'h22f7d0,
25'h408a03,
25'h6c301d,
25'ha5847b,
25'he884f4,
25'h12e329e,
25'h16ead07,
25'h1a3c49c,
25'h1ffffff};
