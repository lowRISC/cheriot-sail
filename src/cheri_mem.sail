/*=======================================================================================*/
/*  CHERI RISCV Sail Model                                                               */
/*                                                                                       */
/*  This CHERI Sail RISC-V architecture model here, comprising all files and             */
/*  directories except for the snapshots of the Lem and Sail libraries in the            */
/*  prover_snapshots directory (which include copies of their licenses), is subject      */
/*  to the BSD two-clause licence below.                                                 */
/*                                                                                       */
/*  Copyright (c) 2017-2021                                                              */
/*    Alasdair Armstrong                                                                 */
/*    Thomas Bauereiss                                                                   */
/*    Brian Campbell                                                                     */
/*    Jessica Clarke                                                                     */
/*    Nathaniel Wesley Filardo (contributions prior to July 2020, thereafter Microsoft)  */
/*    Alexandre Joannou                                                                  */
/*    Microsoft                                                                          */
/*    Prashanth Mundkur                                                                  */
/*    Robert Norton-Wright (contributions prior to March 2020, thereafter Microsoft)     */
/*    Alexander Richardson                                                               */
/*    Peter Rugg                                                                         */
/*    Peter Sewell                                                                       */
/*                                                                                       */
/*  All rights reserved.                                                                 */
/*                                                                                       */
/*  This software was developed by SRI International and the University of               */
/*  Cambridge Computer Laboratory (Department of Computer Science and                    */
/*  Technology) under DARPA/AFRL contract FA8650-18-C-7809 ("CIFV"), and                 */
/*  under DARPA contract HR0011-18-C-0016 ("ECATS") as part of the DARPA                 */
/*  SSITH research programme.                                                            */
/*                                                                                       */
/*  This software was developed within the Rigorous Engineering of                       */
/*  Mainstream Systems (REMS) project, partly funded by EPSRC grant                      */
/*  EP/K008528/1, at the Universities of Cambridge and Edinburgh.                        */
/*                                                                                       */
/*  This project has received funding from the European Research Council                 */
/*  (ERC) under the European Union’s Horizon 2020 research and innovation                */
/*  programme (grant agreement 789108, ELVER).                                           */
/*                                                                                       */
/*  Redistribution and use in source and binary forms, with or without                   */
/*  modification, are permitted provided that the following conditions                   */
/*  are met:                                                                             */
/*  1. Redistributions of source code must retain the above copyright                    */
/*     notice, this list of conditions and the following disclaimer.                     */
/*  2. Redistributions in binary form must reproduce the above copyright                 */
/*     notice, this list of conditions and the following disclaimer in                   */
/*     the documentation and/or other materials provided with the                        */
/*     distribution.                                                                     */
/*                                                                                       */
/*  THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS''                   */
/*  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED                    */
/*  TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A                      */
/*  PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR                  */
/*  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,                         */
/*  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT                     */
/*  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF                     */
/*  USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND                  */
/*  ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,                   */
/*  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT                   */
/*  OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF                   */
/*  SUCH DAMAGE.                                                                         */
/*=======================================================================================*/

/* CHERI interface to physical memory.  We use the metadata facility for tags. */

/*!
 * THIS(addr, aq, rl, res) reads a capability from the [cap_size] aligned
 * [addr] and returns either a [MemValue] with the partially decoded
 * [Capability] or a [MemException] indicating failure. [aq], [rl] and [res]
 * are flags controlling relaxed memory ordering and atomic memory access 
 * (not used on single-core MCU).
 */
val mem_read_cap : (xlenbits, bool, bool, bool) -> MemoryOpResult(Capability)
function mem_read_cap (addr, aq, rl, res) = {
  let result : MemoryOpResult((CapBits, bool)) = mem_read_meta(Read(Data), addr, cap_size, aq, rl, res);
  match result {
    MemValue(v, tag) => MemValue(capBitsToCapability(tag, v)),
    MemException(e)  => MemException(e) : MemoryOpResult(Capability)
  }
}

/*!
 * THIS(addr) reads the revocation bit corresponding with the revocation
 * granule aligned address.
 *
 * The verification flow does not currently support this
 */
val mem_read_cap_revoked : xlenbits -> bool
function mem_read_cap_revoked (addr) = false

/*!
 * THIS(addr, aq, rl, res) announces the effective address for an intended capability
 * write to the [cap_size] aligned address, [addr]. It returns
 * either [MemValue(unit)] for succeess, or [MemException(e)] indicating an exception, [e].
 * [aq], [rl] and [res] are flags controlling relaxed memory ordering and atomic accesses
 * (not used on single-core MCU).
 * The non-exception case should be followed by a call to [mem_write_cap] with
 * the value to be written. The write is split between address announcement and
 * value write in order to permit certain relaxed memory ordering behaviours when
 * integrated with the RMEM concurrency tool, but the address annoucement
 * may be ignored in sequential execution.
 */
val mem_write_ea_cap : (xlenbits, bool, bool, bool) -> MemoryOpResult(unit)
function mem_write_ea_cap(addr, aq, rl, con) = MemValue()

/*!
 * THIS(addr, cap, aq, rl, res) writes the Capability value [cap] (including tag)
 * to the [cap_size] aligned address, [addr]. It returns either [MemValue(bool)],
 * indicating success (with store-conditional result) or [MemException(e)]
 * in case of exception [e]. [aq], [rl] and [res] are flags controlling relaxed
 * memory ordering and atomic accesses (not used on single-core MCU).
 */
val mem_write_cap : (xlenbits, Capability, bool, bool, bool) -> MemoryOpResult(bool)
function mem_write_cap (addr, cap, aq, rl, con) = {
  let cap_bits = capToBits(cap);
  /* Assume that conversion to bits and back does not change the capability.
     TODO: State closed-form normalised-ness criterion that implies this,
     and prove it as an invariant of capabilities in the system. */
  assert(capBitsToCapability(cap.tag, cap_bits) == cap);
  mem_write_value_meta(addr, cap_size, cap_bits, Cap, cap.tag, aq, rl, con)
}
