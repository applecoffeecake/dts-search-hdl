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

parameter M = 140; // max mark 
parameter k = 4; // num marks per block
parameter SKIM = 8; // uniform prng source width 
parameter SIZE = 64; // lfsr size 
parameter SEED_LIST_SIZE = 100; 
parameter [SEED_LIST_SIZE*SKIM*SIZE-1:0] SEEDS =
{64'h43c0d48dfd2c486a,
64'h2855aeeea6817f69,
64'h89b05834fdb252c3,
64'hb4376bf8dbce7c3d,
64'he93f0c3ab349991,
64'h3e7add79c2fdff16,
64'h96edc87f5ed78b92,
64'h32e0a31f6907ddeb,
64'h520bcea3e9490a73,
64'h8ea5ba5d1ab144b4,
64'h2bf1aed59cf70524,
64'he4cc399f02a2685a,
64'h74b247742d2a993c,
64'he7880a85dba9ffb4,
64'h44f2ba62027823ae,
64'hf14310994c860ce4,
64'hcd6d7f15a9c2978a,
64'heb00b14dca3cf6f9,
64'hb966973949291610,
64'h89ee25779a5a6ac5,
64'hfd781ce3dba203d7,
64'h5dcb2596b75a4bab,
64'h6332eaf58a5645df,
64'h4cdbde1581f8f19d,
64'hc3c6a31ee51e5b64,
64'h14aa95034b5372af,
64'h6de4fcab3f8bda2f,
64'h3bbc10399232300b,
64'hc0c10b85369fd944,
64'h46bdb6bd36a1a638,
64'hb416aaab6c87f60d,
64'hb8474a321b8db397,
64'hc3dab331779a39f2,
64'hf003d668f0945692,
64'hddd96ae7e9a6f4d4,
64'he1938364b2f9da2c,
64'h19dd97e5ce7b4aa7,
64'he6fe14ab870393dc,
64'he3ab9525ca65c415,
64'h6d14f08eb1fb4cf0,
64'h5107fcc65607badf,
64'h40f1726edc17a4c9,
64'h9a2c64ecfc48ded6,
64'h3358f00e3745ed5f,
64'h58280c1c9f9fa05a,
64'h721713b618bfa822,
64'hb97786758a8c4215,
64'hec890a6964f44224,
64'hdf69410af2c298cc,
64'h3f86c4659ffc8c1f,
64'h68f2fdb11becbcc8,
64'hf1ec9c2fc842d0dc,
64'h353298c27db55d1c,
64'h7a98f060b7d02900,
64'hf908515dc3befc3d,
64'h6f49d8f0334238c5,
64'h27ffaaa31fba6d1c,
64'hb238b60ac7a35f68,
64'h7b123e2025fbb514,
64'h1a4c5f45e4357ffa,
64'h598d97326ebb3296,
64'h785898c3bde83d62,
64'h4591e50cf47b4e7f,
64'h7eff6e65371b75e0,
64'hb45844b4a7aa1cc,
64'h9af73d01c7ed9106,
64'habe74e9c864cf35a,
64'h2d99b094a20e890c,
64'heb435764f9a8725f,
64'hb09a93b071eaf936,
64'h5d79fed98b56e14a,
64'hbb48a39d911200dd,
64'hd9764fd302c529dd,
64'hd824ab9bdd19f92e,
64'hde2e5ded0f6081d3,
64'h1929d42065838f93,
64'h117724c208218783,
64'ha469dbae7ce6d7dd,
64'hbee2296cb100567d,
64'h9d65931831d3770d,
64'h72aaf64c7eaaf1ab,
64'h3087165dd9537a88,
64'h7c496cecad501152,
64'h1c68487ed6bf3822,
64'h5d08855cb63539bb,
64'h402890a767f11f4b,
64'h69efa02888151151,
64'ha92ce6b3de033230,
64'h883995233c6fb360,
64'h6343b4413c5c5dc8,
64'h52936a6cc3b8b26c,
64'h2be488c1918c1185,
64'hd5d324fb30418e17,
64'hb5d26199ffb58c75,
64'h3ea446a243d4559b,
64'h68e4e0023616c7f2,
64'hd0f89c4c208509e9,
64'h8ad31e09feeaf6f9,
64'h51f6323cb97358cd,
64'haad033cb5c355b7d,
64'h806df4df5b7e29d8,
64'h3cec5c03f38f726d,
64'h318afdee156a8567,
64'hbf381905fb48a2bf,
64'h71a64ed18c39245,
64'ha6166926b9a4e1b4,
64'ha4c1750bdfdc7bc7,
64'h27925624a27531d1,
64'hf6b055373117790e,
64'h31f22829e4a338ab,
64'hbb341405d49f46df,
64'hecbdd3b2f8b465ad,
64'hbc235ce92191507,
64'hcb67814cb6ddc039,
64'hd40066b285124f60,
64'he5cacc2aacc3339f,
64'hc94ca78d169c0cb2,
64'h89bdb05568691c72,
64'he99c2e2dec74503a,
64'h8664288445462a7c,
64'h559370d7a0dc5acc,
64'h97ec6a7ccdeda3c4,
64'h3ca05344f2849f27,
64'h6022b11edf00720d,
64'h2e5d97cfaa3f81aa,
64'h7f1580df58094043,
64'h8bc2f9d0b6e87f4b,
64'h69077004c69977de,
64'hb43d37fc8dbe6886,
64'h1a76537d0e5a4fe4,
64'hc9e849b370923761,
64'h658842142f4dbd57,
64'h5a7f99ec09d018b9,
64'haa48728d9cc0840,
64'hc9c4b6d6a7d4bde9,
64'h4c1cf1df22de6ec1,
64'h7b41bcde13ba0789,
64'h95938155eacf3c0c,
64'h2bfcb4a2bddf9470,
64'h7821a5a360718ce0,
64'hbc1951954d507027,
64'hcf92c232c80dad40,
64'hb7b11062f0cd1740,
64'h7c7ba0c606d23e19,
64'h50be7d65e1103686,
64'hf6b7bf45ba80996b,
64'h499ecc35921e41fd,
64'he1dd57b5a73b1b1a,
64'h826bd9b246888b3,
64'h8912d56f33405b25,
64'h76e40936de81cd31,
64'ha352e73ebe9b74bb,
64'hce006df645bccab9,
64'he44012235c856e9d,
64'ha59676a04a99d7a4,
64'h4cd24bf02db6986f,
64'h25f4d8cd035a9550,
64'h744bc2f33a3d40c8,
64'h3dbac041ef3ae3f9,
64'he619b9fb5d616429,
64'h912dec16b32ae51b,
64'hb94b7780ddcf0271,
64'h4abf5b14e28da1a6,
64'h8e9cfdf39796552,
64'h65f77c50c76cd297,
64'h786f8d639d38c925,
64'h5ea53058cf005ff4,
64'hefc9af27d730da9b,
64'h58460357bd0536db,
64'h5bbec154a1d084f4,
64'h4136ecaa13a39567,
64'h59fa39bb9a60ed8b,
64'hcc4e995c303fc339,
64'ha8931e28de95c3b0,
64'h36278d9aa0db7a2e,
64'h458eebc1713a4591,
64'hbf726866d21eae25,
64'he193ba56e03ba574,
64'h5a2f1892585f7191,
64'h69c0130e9aaef232,
64'h152e2e3c6176f007,
64'ha705af43bfaa641d,
64'h9a5ac3bcaca55cb5,
64'hd22ab77f4205936,
64'h4f5b7c78bc6e1908,
64'hac02d88dcc8bc5d4,
64'ha3937067344185e9,
64'h75e46899d265b0fe,
64'h47af5d43976c7964,
64'h2a9c36a66111ec75,
64'hf376a0590fdd41cc,
64'hfd5e21ac7ef7fc35,
64'h472f414604008431,
64'h20908ee148b167eb,
64'h27335f361c91a2d2,
64'h405a64c7adaaddee,
64'hd5a690b87e768465,
64'h366c374ac145dd98,
64'h4ee4011a13939774,
64'h101158b573f8c7cb,
64'h9ecf422368a1e57e,
64'haf910b75297743d5,
64'h97ff415d076e46b9,
64'h1327e5818f61397d,
64'h92365d0e3613483c,
64'hbac3bc7b837ba975,
64'hffc970e2d8996a8e,
64'h960f6853661f42c6,
64'h16b1811121e4fb47,
64'h39cd2791e4b907f4,
64'hcf9b524ad76c717d,
64'h53d8fe09d15302f,
64'h9668e4b643b2a319,
64'h10bf228039ae0457,
64'h4052b5066bab0691,
64'h9855a4d587b907cc,
64'h72b1dfaad4b84e6a,
64'h3175a65d7a3472ad,
64'h3ebc12f7d6d76715,
64'h3a6f66131962b037,
64'ha8e2ce098d8d2c08,
64'h8cd9bd2a06c58369,
64'h2a62941765e892d3,
64'h4364f0eda261f9fb,
64'h521775d35f4a3810,
64'h20271aa149babe5e,
64'h2d08737306f15043,
64'hf4c6e28adda9e762,
64'hbe2c709c47077833,
64'h13e2ed90630ac0e1,
64'h217d6347ffb68495,
64'hcb270becfa1977e8,
64'hd8c8a2532f01b15f,
64'h514dbe66ba1ac4e2,
64'h6e0cd571a816cdc7,
64'h197fd31e6f76d6cd,
64'h1a89c409ec1846f3,
64'heaa9957765ad114e,
64'hc33b8ba3ecb9829d,
64'h544a474a5cf03a5d,
64'he465a089b5937afd,
64'h6309190e59facd45,
64'h363661dd98f8f5bb,
64'h20060a327a90d0e1,
64'h45a049346dc3ea25,
64'hb9e32dc38fb0259c,
64'hd8eee7186a3b65ea,
64'hd6d706c8d58a42f5,
64'ha3ddb0e0e4be568b,
64'h80a96ed3fbfe87c2,
64'hee77f2ff03b49bfa,
64'h3749b16d9956dd1,
64'h259439125ac8530b,
64'h81036e237868cc1a,
64'hd6d244e490441196,
64'ha68f243c382f6262,
64'h40a8208540d95f6a,
64'h92dd88ecd200e793,
64'ha1d675af131f6b80,
64'h38012a8385fed534,
64'h4270a75da5b9669,
64'h93ad71075ac6e74f,
64'h36880c810eade9d4,
64'h2eb0fc8ecfe514fc,
64'h81fc30ce56e9b7c9,
64'h7be5c0df81fb1cae,
64'h9321f697f02dae05,
64'h3d897eabdaca658,
64'h67cf87933109cfca,
64'hf035e6ec43dbc3ad,
64'h3cad1c3591c71cec,
64'hb904f8df866c2806,
64'h4fb6a139a5b3618,
64'h9728c70100f082b0,
64'h517c9352e3fbec8,
64'hfe95a398ef329b57,
64'hd46e1eb20da13068,
64'h22c77ea7964c8966,
64'hf075058e2e6e0e7a,
64'h3867ec6d7d753e89,
64'h3ab13e1e50764f3e,
64'hcef995c22a54e096,
64'he5ca497e530bef0a,
64'hb2bb36f1f75a6ccb,
64'hedb296cc70dca342,
64'h164eb8027c2a1890,
64'h8fbc6539d9b6b3a,
64'h23b6d0ffee194406,
64'hee42bd11902fd548,
64'h2699a188b63edea9,
64'hfa49372a2332b97b,
64'h61f13475bc83bce1,
64'h7895bfa42f86861e,
64'hdf0a0d65a7b734c7,
64'h55bda16af8d4d1c3,
64'h7ad214465b9ce96c,
64'h554d32e2d056ac0d,
64'hc0ef37dad3cd914a,
64'h2e9b4e53c3076228,
64'h390794513327e1ac,
64'h3441e474823d650a,
64'h6817385dfcba53aa,
64'h23b385eb05ed0cba,
64'hf1237e20fec3b693,
64'hca65f60dc06ba2d0,
64'h130ac463c03e25ec,
64'h896718847e3bf606,
64'hc6eb3fc638c82d4c,
64'hd7fee385e6684c98,
64'hdf5f5f3b8600bb58,
64'h85d304a4feca4bc,
64'h37c93a78d47e55a3,
64'hfda4298ebabaa7b4,
64'h5997e64d98bfabe3,
64'h3008007dc582b081,
64'hc078ef0a9a5dc2ab,
64'h8d2212635c44e9c2,
64'h65f987e1a148fda1,
64'h7d7e39de93fa957f,
64'h805557e9bf61dad6,
64'h173871f126ada20f,
64'h218a10e642ac037a,
64'hb6276e7df43e65ba,
64'h8361c1f1feed273e,
64'h38c28b76c1f168d4,
64'h58ee33e10e2c34ee,
64'h7c8777a529548f64,
64'h6eb457b044e35b5b,
64'h404d8101e66badb1,
64'h3eda76990a57ff1b,
64'h472045e5997c1095,
64'hc85b614f44b3dfb7,
64'h1e28ed69d1f98861,
64'h715330904687b497,
64'h26e2235b571801cb,
64'ha3e52d98847084b2,
64'h88f499dfa943554c,
64'h25e33ca50d3f7f9a,
64'h6043fe16ebf35f2f,
64'hfe4b1255530ac93a,
64'h25c6ed5a5b263158,
64'hf7cfbd544dde8d4f,
64'ha5ea7c70faacc875,
64'h223a5b9fa795dc6d,
64'h7aedf9e1495a7074,
64'h559e055ef98d0785,
64'h2cdae8bb68e7dcee,
64'hb1841ce967c5706a,
64'h8dcb21db1a384be4,
64'hd25c5b67f2ea9b31,
64'h4726db62ba380e46,
64'hd73e8520390803,
64'hee91e38688db571e,
64'h802e2c5584c8bd0d,
64'h4982ae9c255ec8c1,
64'h3e31c0b59dcd28be,
64'h92488474080d870a,
64'h119731da3d49d1e7,
64'h48c76508b387acaf,
64'h1059823c0c867c56,
64'h384a0fc0571f267c,
64'h8a6e561cfcee8a48,
64'h20ecc05c22dd38a5,
64'hb7b4293fc06f5042,
64'he656abdeb5d949ab,
64'ha10e8857af92c019,
64'hb4abd01d0f2d5869,
64'hc32a4e57cb9b0e34,
64'hd0210b2d1c259d14,
64'h5a211582c3114fbb,
64'hd9dbb37740a2a059,
64'h898a1da951c98465,
64'hcaf03ed26fec1e54,
64'h75f5a1cb5820fa0,
64'h69f599524b6fd279,
64'hee81876eed431bf4,
64'hac7699da2bab3fca,
64'h2f83817d0a0a2ef8,
64'h46817ba19c95639e,
64'ha02103a4d1e27a31,
64'h930369e77317e7c9,
64'h7e05375f4f593a43,
64'h99900d38b6e3fabf,
64'h788050530a8e984f,
64'h9e29c6fe90a76082,
64'hb913e6635a8d8a42,
64'hd892b5593ff5b8ae,
64'hdeb38a8a30a92b72,
64'h316948620b8c9fd1,
64'h6c7cc5298d5d6d99,
64'hebfd7a825527f270,
64'h3f41eeaf787f57e4,
64'h66e1ba05e378e399,
64'hb24b3bce4aeaadda,
64'hb97099834f63b504,
64'heab54a3d2c9116e0,
64'h180d9e5272a0b7ac,
64'h164386f2f24b5534,
64'h1548240893595899,
64'h6830f3e7ae518ffb,
64'h85035e0cbcf1c48c,
64'h370dab82ad335471,
64'hc98e66852c2a51ec,
64'h6672342bc93744bb,
64'ha91f593db83ae413,
64'hb62becf4658e5ed3,
64'hd50f99dbdc4121c2,
64'h681acb1cfdbc324e,
64'h20f6ba3c314226df,
64'h2bebdb4a7efc9184,
64'hfa4d383f941f6d54,
64'h5540f2c79c009a1b,
64'h39e4d97a6043328b,
64'ha31063d5c0a3327a,
64'hea3ef358cf3be670,
64'h9f1a579ae819430b,
64'h894718bef39203bd,
64'hdda726b6220eef45,
64'hd9adc5ba5fac7ec3,
64'h592c17fdb7efa9e7,
64'h6d469928b0a99f4d,
64'h393a134d370159b1,
64'h404b18df736c8aac,
64'h876485aec144bf6c,
64'hd3413bc356dcf2f,
64'h7a84cb9f12538ace,
64'h26ad3f12779ee51b,
64'h35168aaa79e28aa3,
64'h5941a72015ab39e9,
64'he1743450b400e70e,
64'h6e8744d3cffde6ed,
64'h787d0537a9216a9f,
64'h5ac580873d6be88e,
64'h6c5ee4555f51546a,
64'h6d836729d7e62998,
64'h438c569a74291898,
64'h12ebb1f59adc432b,
64'hd01f872239ecc6f2,
64'h9c7b25da0d570dbe,
64'h16b78c431e97c6b0,
64'h7b5e2e0e0a0c7a1e,
64'h790272b8255c6137,
64'h50215743a62db925,
64'hcdede96cb62ffdd5,
64'h1f0956c97041e45c,
64'h6f6be1c83b259e6f,
64'hf6c82613cf1e9616,
64'hc710da45b8d606c5,
64'h557ad626962d0573,
64'h53905596af05726b,
64'hf6465fa830309d3e,
64'h11a16a98e7e4cbaa,
64'h523ae41a81754f16,
64'h86f76317bba80974,
64'h6a4c8cc9af554b52,
64'h5ae4f4d99c9b112b,
64'hfab8fc1df62d838b,
64'h6df11e7ccbb27910,
64'h56135ba90ef1fa6f,
64'hae76b525f26efaa5,
64'h6d6373ef794ea0a9,
64'hab02bfb43239aebf,
64'hbc489c43576d4332,
64'hd436f115b0aacdb4,
64'h28a733a4650b45c7,
64'h7cb823f2c13ba022,
64'h4e89ecee02cc3a93,
64'h77d7f79594cc5d78,
64'h17a3d023d4c017d3,
64'hc7dafb3754cc269c,
64'he06109a54eff8f85,
64'h7cdedef951d93eb0,
64'h4aafc99c10446fe1,
64'h18354b93705f35c0,
64'h9c3106e5dbc562e2,
64'h631ab974e02b731a,
64'hee7ad7c3fc51a142,
64'hcfd7c2e39043c033,
64'he38975f846cbadb8,
64'hbe99a81b0d94088c,
64'h8457dadae917e084,
64'haa9fec63ff11fd5d,
64'h2417003ac6693f8c,
64'h7219e38fa89de709,
64'h986c13a5974b9ffc,
64'h7eef7cd91c7421d6,
64'hdcfd75369a425eb1,
64'hb6ee1d4f877a08d3,
64'hb0b4045d355ef958,
64'hac9bc0a81f1114ec,
64'h70d84e21b5aa212,
64'hbc5b8d9473663fe,
64'h250acf28e325ec53,
64'h57ab623fa8281dfa,
64'h18116fc868e13ece,
64'h7624fe63b6f85067,
64'h271dda5cb5acf29e,
64'heb7a4a8caccc70a4,
64'hba2337bc7a21f327,
64'h71dfc4c449dbd613,
64'hb9a89d286a5d09b8,
64'h3a0cb0f1df77f2ce,
64'ha1c4ca2377a75bf,
64'h9f30b31c3b661806,
64'h689274727b1ebd60,
64'h3aca293e8a3c1676,
64'hd14fa0f7f4c19bd4,
64'h83f8f4c34eb9e0e,
64'h4577134a22d44d5f,
64'hdaa5e153eb6b9ac0,
64'had580f5cc15b28db,
64'ha47078080d08bbd1,
64'h9aac9ba1f3c7edb2,
64'h9cc3aa9b06899fb9,
64'h5bb89af4f816b839,
64'h45587bf67c5ace28,
64'h48c06cfedfb30f72,
64'hc02e4f208ba98a40,
64'h698bff1d60c56e51,
64'h4f17d2e9694772aa,
64'h70dea8101f1fb646,
64'h3c700bb4442b6b4d,
64'hd5dabe642830180d,
64'h2a9b36bdea8db19d,
64'hefd3cecb967149d5,
64'h9ebf7029680cc948,
64'h61808713e0277658,
64'h3b32e9a081a98f96,
64'h56b595a5924abf52,
64'h5e25f4d123ec74cf,
64'h261a22b980ec452c,
64'hc1b2a4c6f11e6193,
64'hbb6161edbbd771af,
64'h7a043fc11f47445d,
64'hf70248e1d4b80f5,
64'hf5533f0d95b581db,
64'h66e858c7b6e2b1f7,
64'hf2b86e1928c9397e,
64'h8df5ef0c772516c3,
64'haafcf18df585e412,
64'hddb9764fd9e3b2f3,
64'h57c46190f0fe2c4a,
64'ha9218f2c4bab2be,
64'h4149636be3bea8dc,
64'hf9d271d0f6ebd037,
64'hb430073e3428e60d,
64'h4c98b55dc54bc23e,
64'hc032f8d1bf23778c,
64'h54e9d51657417b0d,
64'h5a2985a4499555b2,
64'hec7b591f8bfb49b1,
64'ha96c48a33d7f0a0d,
64'h3960b9212f7a4737,
64'h60e89ab1f72210ff,
64'hb5c0de9095b35b74,
64'hf9fd313e3a47c017,
64'ha155e7ecdc89a06d,
64'h27500dc5aa5b7ce3,
64'h6e94592ef1947c4d,
64'hccbc4018b41b17bf,
64'h6d290ac44bc366ee,
64'h3887e0924f84ce1e,
64'h98e76451d86e0cad,
64'h7e8e772e1e3fb7a6,
64'h111e416aaa23f20d,
64'h285792c007a8ddd7,
64'ha352f0fa59da84da,
64'hd2a2884c5e609a9d,
64'h4e2375748465cdac,
64'hba282a04a0ce3430,
64'h26379410f64c90c8,
64'h57b0cd50ffbfe979,
64'h38e0e5f6cd8c4a8a,
64'h77bcf1605d00a1c4,
64'h90d51fe5a6018820,
64'hec419baf3c7f2c67,
64'h175251b7a3c336c7,
64'h8e749128f3f28cf2,
64'h428062aee97fa5d,
64'h8da554d2c76b257d,
64'h922a6a3891c8ecf6,
64'hf859e9618432d49c,
64'h4ca3f3d93a4cf25a,
64'h5f76acfbabfdc4e2,
64'h2e04695a0a20b63d,
64'h693ba5b34dcd10d,
64'h17dee3340f7e84d3,
64'h4c2ff5146635f76b,
64'hd9f153982297d670,
64'h878838fede1f4b25,
64'hf4a44fbf39e3ac4a,
64'h15c438dea02cdf36,
64'ha03629b9651f44e,
64'h8881f13291170d8b,
64'h6003d5b1a673485e,
64'h73f86a4a08af03c,
64'h95900f29a41d2f08,
64'hdad5ca15cdd5e34c,
64'h222753ae96803afc,
64'h37033d37f4808d3f,
64'h6ef1eaa024a59d1a,
64'h45e86902f496536a,
64'h99ed3d46c0d5e825,
64'h74b7b8c8179da1ae,
64'hf519257fae094b4f,
64'habd5d52071f010ee,
64'h12ba5da7134b0ea8,
64'hc8a1ddf6b1188bee,
64'hc7d30ee123d57ca2,
64'h1f9c6eab9bd4dd42,
64'hb00a7599a88e4409,
64'h4bbc7cf4a06f2151,
64'h9a6f3baa3b482a00,
64'h802adb9861a80665,
64'hd0e303621f051985,
64'hdbe68f2081b873f6,
64'h889cca26111a0742,
64'he476388ed7fdbbcd,
64'h2cd753bfdba9442,
64'h99fa165a13431e36,
64'hf93cd496e55cfb38,
64'hdbbfb725c0a547cc,
64'hdfb8142eec3091e0,
64'hffa25ae62bdfc321,
64'h68468d859f08275f,
64'h6bfe70e99f4f61c8,
64'h17054daeeb9f85e0,
64'h48f7d37f36334572,
64'h37045caeef41a527,
64'h8767626486aeb0ce,
64'h50ebc6f7128360e0,
64'h672d60c920cad249,
64'haa5b92bfb624e346,
64'hb5649ee7aef7dcc7,
64'h79001f9ee1af961a,
64'h9de69a00d1058d29,
64'hbd52b9570a3dca49,
64'hccc1f2c4d40ab47f,
64'h2a4d2a87f7290d5f,
64'h8ce04ad8e99d52b8,
64'ha5b90161bc82f8d0,
64'ha8278c94894a55c6,
64'h4dc3da5aacbb3545,
64'h2ba4f034b6bcc0c1,
64'h29619cbfc6818097,
64'h20e386ad48e04761,
64'h46a4b91277461bf,
64'h7abd17034360520d,
64'h771250eec4ffb914,
64'hf2d06b4474f7c4bc,
64'h6cb9aa95473dcfb3,
64'h3e453fb7cf384a4,
64'h79273be4b2ae5a1d,
64'h62853c919db51d88,
64'hdde7477ceaf664b9,
64'hf6e32a7a8bfb5cda,
64'hc31b5703d71a4cf,
64'h6a3e593cd59260e1,
64'h694219da67a4ad84,
64'h801c550b84264411,
64'h6ace6a1f91d0f12c,
64'h89a64ac18fb6e2e2,
64'h88b5adf9e4f008bb,
64'h228a7cbb919d65a5,
64'hff15d09c94af0a84,
64'ha8eb111fd79ab8b9,
64'hc513a795bebe42a8,
64'h4de02cdcf43768af,
64'h3b3536b6e0765db8,
64'hb973bb2f87564d5d,
64'he2091d6cff608041,
64'h75da6afa491b4d67,
64'he7bb4bd91a31622b,
64'hc972f090fe9005f5,
64'hec38a276ad2f3cd,
64'ha5ae40afdecf9f0f,
64'ha94df57c72686d1e,
64'hd0afbd59fe503117,
64'hd85d5421ebd4e05e,
64'hcaca75f96faf4f78,
64'hdadbede68c1d7ecd,
64'h79085085b7d4d467,
64'hd12786a50b1fa847,
64'hb0b8f05b0046a175,
64'h85e5b23c08ce8e50,
64'he38b42feb67ad45b,
64'hb2fa1bf8e036bed1,
64'h27aa189a0273040,
64'h99b2a49bb305271a,
64'hc63e015e57d5a472,
64'h5ef1bdbc9ae1370e,
64'hedb1e8c07dd7eb9,
64'h10a3b41be3075a95,
64'h43d9e75422044f3b,
64'hb6c169bef928bf54,
64'h13c4758d33a6a85f,
64'hf28f12514d59846,
64'hae3c10eeaac88a0f,
64'h8059bbaeff076f65,
64'hed40c069ddc67334,
64'he3c08ccb738bc0b7,
64'h550eada6d2a9db16,
64'h3f8d914caedb715c,
64'h3d45393fc45336d4,
64'h9012e19eb7056844,
64'he8d49c833a7d0fa1,
64'h36af77ea788e70d3,
64'h9cd69aa34ea80d85,
64'h679ceaa4f31f12fd,
64'h2e773c1a24e78412,
64'h6038358bb7083e35,
64'h582d56b82123e4c2,
64'h945c51a877caf590,
64'h717778b94c0adf30,
64'h91237ec4692ea10e,
64'hbb3bb641a1918c03,
64'h2d1941c37b815b82,
64'h495cee8edb5c4060,
64'h27c357a0ee19974b,
64'hf5f2999a4191bc9e,
64'h4ccfdb337b8dba38,
64'h397a856edb667bf7,
64'h72bbaf274bb8e2df,
64'h85cd379fe99be97d,
64'hce3d8105060e803c,
64'hc40433b9e673d2cc,
64'h91e0b52b61670870,
64'h7e277ea9da27edfb,
64'hd10aaf32a3e6145e,
64'h622772f4613c4cae,
64'h355ec756805fabbf,
64'h29e156faea077910,
64'h6f04e76c80580927,
64'h6bf8f8cfe990a0cc,
64'hec3a220d92b97aad,
64'h7217f9a04ec32607,
64'heec51b857e4bc937,
64'hc1b319c8557f098e,
64'h5be8568823a1cbdc,
64'hf82989a5389e3b50,
64'h2f049426ac6e8015,
64'h2ab3ec60a4a32a86,
64'hd1774d441b1ed13c,
64'hebd80b6186fdc953,
64'hea8b63f3bfeb130,
64'hb2106e3d55e59657,
64'h34d19331e43e1cd9,
64'h28566f883bb48899,
64'ha0b9b9f799117c73,
64'hf8d687ebe4c7aa8,
64'hf68128e342c23c8d,
64'hd276c88b06960aab,
64'hba65020960d8f4b2,
64'h82073483c2bc15e7,
64'h524417ba065c9f19,
64'hc4a1028fedde36bb,
64'h4be48efe52617be7,
64'h4e5caa440bbcc845,
64'hdd1c0a68177d4187,
64'h96f441df8b2cc086,
64'h9033f06ea2ed64f8,
64'h9b9c3f10d8673db0,
64'ha43eebc5a79c737f,
64'h48e7898627eb6104,
64'h34adfaa3fe434b78,
64'h408bceeeacf28106,
64'h97d65a44556ff077,
64'h795f9df23491536f,
64'hb2f4342683df4346,
64'h16dc904244e1216a,
64'h8e2c88b2ab2ab874,
64'h3c60135c975f4750,
64'hdf6cede797db8481,
64'h26641b6a19a86534,
64'ha4051839f0edfabb,
64'h9bd7057e0ec553d6,
64'hc7e9b77540126d1e,
64'h27f9876f2b9b632d,
64'ha67cf2d783a21501,
64'ha2ba54352083f840,
64'ha86c86249a31482a,
64'h1f387afe156755a9,
64'heac30e9451e226b0,
64'he12e34e915d07b4f,
64'hbf3e1219ba3b8cf1,
64'h1db1e88a81083d3b,
64'h82f44d833f446db7,
64'h783abe8750db418c,
64'h11f91a2244851ac9,
64'h7348f02967101ac6,
64'h2569f9871ab412fd,
64'ha572d8873b4d4576,
64'h6998a431679c8f48,
64'hb09762cd544b6513,
64'hd71b85b91470df56,
64'hb9dfa02e2f80fe21,
64'h3eb6d5f307907db6,
64'hcc25760341a3a044,
64'h2ba21e7ec4175766,
64'h14b944941281e8b8};
// lfsr prim polys 
parameter [SKIM*SIZE - 1 : 0] PRIMPOLYS =
{64'h8000000000001868,
64'h80000000000018f8,
64'h8000000000001933,
64'h800000000000193a,
64'h800000000000196c,
64'h800000000000198b,
64'h80000000000019a9,
64'h80000000000019e2};
// boundaries of bins to produce k different non-uniform distributions 
parameter [SKIM*M*k - 1 : 0] BINBOUND =
{8'h19,
8'h1c,
8'h1f,
8'h23,
8'h26,
8'h2a,
8'h2d,
8'h32,
8'h36,
8'h3a,
8'h3f,
8'h44,
8'h49,
8'h4f,
8'h54,
8'h5a,
8'h5f,
8'h65,
8'h6b,
8'h71,
8'h77,
8'h7d,
8'h83,
8'h8a,
8'h90,
8'h96,
8'h9c,
8'ha1,
8'ha7,
8'had,
8'hb2,
8'hb7,
8'hbc,
8'hc1,
8'hc6,
8'hca,
8'hcf,
8'hd3,
8'hd6,
8'hda,
8'hdd,
8'he1,
8'he4,
8'he6,
8'he9,
8'heb,
8'hed,
8'hef,
8'hf1,
8'hf3,
8'hf4,
8'hf5,
8'hf7,
8'hf8,
8'hf9,
8'hf9,
8'hfa,
8'hfb,
8'hfb,
8'hfc,
8'hfc,
8'hfd,
8'hfd,
8'hfd,
8'hfe,
8'hfe,
8'hfe,
8'hfe,
8'hfe,
8'hfe,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'h1,
8'h1,
8'h1,
8'h1,
8'h2,
8'h2,
8'h2,
8'h2,
8'h2,
8'h3,
8'h3,
8'h3,
8'h4,
8'h4,
8'h5,
8'h5,
8'h6,
8'h6,
8'h7,
8'h8,
8'h8,
8'h9,
8'ha,
8'hb,
8'hc,
8'hd,
8'he,
8'h10,
8'h11,
8'h13,
8'h14,
8'h16,
8'h17,
8'h19,
8'h1b,
8'h1d,
8'h1f,
8'h22,
8'h24,
8'h26,
8'h29,
8'h2c,
8'h2f,
8'h31,
8'h35,
8'h38,
8'h3b,
8'h3e,
8'h42,
8'h45,
8'h49,
8'h4d,
8'h50,
8'h54,
8'h58,
8'h5c,
8'h60,
8'h64,
8'h69,
8'h6d,
8'h71,
8'h75,
8'h7a,
8'h7e,
8'h82,
8'h87,
8'h8b,
8'h8f,
8'h93,
8'h98,
8'h9c,
8'ha0,
8'ha4,
8'ha8,
8'hac,
8'hb0,
8'hb4,
8'hb7,
8'hbb,
8'hbe,
8'hc2,
8'hc5,
8'hc8,
8'hcb,
8'hce,
8'hd1,
8'hd4,
8'hd7,
8'hd9,
8'hdc,
8'hde,
8'he0,
8'he2,
8'he4,
8'he6,
8'he8,
8'hea,
8'heb,
8'hed,
8'hee,
8'hf0,
8'hf1,
8'hf2,
8'hf3,
8'hf4,
8'hf5,
8'hf6,
8'hf7,
8'hf8,
8'hf8,
8'hf9,
8'hf9,
8'hfa,
8'hfb,
8'hfb,
8'hfb,
8'hfc,
8'hfc,
8'hfc,
8'hfd,
8'hfd,
8'hfd,
8'hfd,
8'hfe,
8'hfe,
8'hfe,
8'hfe,
8'hfe,
8'hfe,
8'hfe,
8'hfe,
8'hfe,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'hff,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h1,
8'h1,
8'h1,
8'h1,
8'h1,
8'h1,
8'h2,
8'h2,
8'h2,
8'h3,
8'h3,
8'h3,
8'h4,
8'h4,
8'h5,
8'h6,
8'h7,
8'h8,
8'h9,
8'ha,
8'hb,
8'hc,
8'he,
8'h10,
8'h11,
8'h13,
8'h15,
8'h18,
8'h1a,
8'h1d,
8'h20,
8'h23,
8'h26,
8'h29,
8'h2d,
8'h31,
8'h35,
8'h39,
8'h3d,
8'h42,
8'h46,
8'h4b,
8'h50,
8'h55,
8'h5b,
8'h60,
8'h66,
8'h6b,
8'h71,
8'h76,
8'h7c,
8'h82,
8'h87,
8'h8d,
8'h93,
8'h98,
8'h9e,
8'ha3,
8'ha8,
8'hae,
8'hb3,
8'hb8,
8'hbc,
8'hc1,
8'hc5,
8'hc9,
8'hcd,
8'hd1,
8'hd5,
8'hd8,
8'hdc,
8'hdf,
8'he2,
8'he4,
8'he7,
8'he9,
8'heb,
8'hed,
8'hef,
8'hf1,
8'hf2,
8'hf4,
8'hf5,
8'hf6,
8'hf7,
8'hff,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h0,
8'h1,
8'h1,
8'h1,
8'h2,
8'h2,
8'h3,
8'h4,
8'h5,
8'h6,
8'h8,
8'ha,
8'hd,
8'h10,
8'h14,
8'h18,
8'h1e,
8'h23,
8'h2a,
8'h31,
8'h39,
8'h42,
8'h4b,
8'h55,
8'h5f,
8'h6a,
8'h75,
8'h80,
8'h8b,
8'h96,
8'ha1,
8'hab,
8'hb5,
8'hbe,
8'hc7,
8'hcf,
8'hd6,
8'hdc,
8'hff};