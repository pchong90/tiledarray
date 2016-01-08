/*
 *  This file is a part of TiledArray.
 *  Copyright (C) 2013  Virginia Tech
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Justus Calvin
 *  Department of Chemistry, Virginia Tech
 *
 *  shift.h
 *  June 7, 2015
 *
 */

#ifndef TILEDARRAY_TILE_OP_SHIFT_H__INCLUDED
#define TILEDARRAY_TILE_OP_SHIFT_H__INCLUDED

namespace TiledArray {
  namespace detail {

    /// Tile shift operation

    /// This tile operation will shift the range of the tile and/or apply a
    /// permutation to the result tensor.
    /// \tparam Result The tile result type
    /// \tparam Arg The argument type
    /// \tparam Consumable If `true`, the tile is a temporary and may be
    /// consumed
    /// \note Input tiles can be consumed only if their type matches the result
    /// type.
    template <typename Result, typename Arg, bool Consumable>
    class Shift {
    public:
      typedef Shift<Result, Arg, Consumable> Shift_; ///< This object type
      typedef Arg argument_type; ///< The argument type
      typedef Result result_type; ///< The result tile type

      /// Indicates whether it is *possible* to consume the left tile
      static constexpr bool is_consumable =
          Consumable && std::is_same<result_type, argument_type>::value;

    private:

      std::vector<long> range_shift_;

      // Permuting tile evaluation function
      // These operations cannot consume the argument tile since this operation
      // requires temporary storage space.

      result_type
      eval(const argument_type& arg, const Permutation& perm) const {
        using TiledArray::permute;
        using TiledArray::shift_to;
        result_type result = permute(arg, perm);
        shift_to(result, range_shift_);
        return result;
      }

      // Non-permuting tile evaluation functions
      // The compiler will select the correct functions based on the
      // consumability of the arguments.

      template <bool C, typename std::enable_if<!C>::type* = nullptr>
      result_type eval(const argument_type& arg) const {
        using TiledArray::shift;
        return shift(arg, range_shift_);
      }

      template <bool C, typename std::enable_if<C>::type* = nullptr>
      result_type eval(argument_type& arg) const {
        using TiledArray::shift_to;
        shift_to(arg, range_shift_);
        return arg;
      }

    public:

      // Compiler generated functions
      Shift() = delete;
      Shift(const Shift_&) = default;
      Shift(Shift_&&) = default;
      ~Shift() = default;
      Shift& operator=(const Shift_&) = default;
      Shift& operator=(Shift_&&) = default;


      /// Default constructor

      /// Construct a no operation that does not permute the result tile
      Shift(const std::vector<long>& range_shift) :
        range_shift_(range_shift)
      { }

      /// Shift and permute operator

      /// \param arg The tile argument
      /// \param perm The permutation applied to the result tile
      /// \return A permuted and shifted copy of `arg`
      result_type
      operator()(const argument_type& arg, const Permutation& perm) const {
        return eval(arg, perm);
      }

      /// Consuming shift operation

      /// \tparam A The tile argument type
      /// \param arg The tile argument
      /// \return A shifted copy of `arg`
      template <typename A>
      result_type operator()(A&& arg) const {
        return Shift_::template eval<is_consumable>(std::forward<A>(arg));
      }

      /// Explicit consuming shift operation

      /// \tparam A The tile argument type
      /// \param arg The tile argument
      /// \return In-place shifted `arg`
      template <typename A>
      result_type consume(A& arg) const {
        constexpr bool can_consume = is_consumable_tile<argument_type>::value &&
            std::is_same<result_type, argument_type>::value;
        return Shift_::template eval<can_consume>(arg);
      }

    }; // class Shift


    /// Tile shift operation

    /// This tile operation will shift the range of the tile and/or apply a
    /// permutation to the result tensor.
    /// \tparam Result The result type
    /// \tparam Arg The argument type
    /// \tparam Scalar The scaling factor type
    /// \tparam Consumable Flag that is \c true when Arg is consumable
    template <typename Result, typename Arg, typename Scalar, bool Consumable>
    class ScalShift {
    public:
      typedef ScalShift<Result, Arg, Scalar, Consumable>
          ScalShift_; ///< This object type
      typedef Arg argument_type; ///< The argument type
      typedef Scalar scalar_type; ///< The scaling factor type
      typedef Result result_type; ///< The result tile type

      static constexpr bool is_consumable =
          Consumable && std::is_same<result_type, argument_type>::value;

    private:

      std::vector<long> range_shift_; ///< Range shift array
      scalar_type factor_; ///< Scaling factor

    public:

      // Permuting tile evaluation function
      // These operations cannot consume the argument tile since this operation
      // requires temporary storage space.

      result_type
      eval(const argument_type& arg, const Permutation& perm) const {
        using TiledArray::scale;
        using TiledArray::shift_to;
        result_type result = scale(arg, factor_, perm);
        return shift_to(result, range_shift_);
      }

      // Non-permuting tile evaluation functions
      // The compiler will select the correct functions based on the
      // consumability of the arguments.

      template <bool C>
      typename std::enable_if<!C, result_type>::type
      eval(const argument_type& arg) const {
        using TiledArray::scale;
        using TiledArray::shift_to;
        result_type result = scale(arg, factor_);
        return shift_to(result, range_shift_);
      }

      template <bool C>
      typename std::enable_if<C, result_type>::type
      eval(argument_type& arg) const {
        using TiledArray::scale_to;
        using TiledArray::shift_to;
        scale_to(arg, factor_);
        shift_to(arg, range_shift_);
        return arg;
      }

    public:

      // Compiler generated functions
      ScalShift() = delete;
      ScalShift(const ScalShift_&) = default;
      ScalShift(ScalShift_&&) = default;
      ~ScalShift() = default;
      ScalShift_& operator=(const ScalShift_&) = default;
      ScalShift_& operator=(ScalShift_&&) = default;

      /// Default constructor

      /// Construct a no operation that does not permute the result tile
      ScalShift(const std::vector<long>& range_shift,
          const scalar_type factor) :
        range_shift_(range_shift), factor_(factor)
      { }


      /// Shift and permute operator

      /// \param arg The tile argument
      /// \param perm The permutation applied to the result tile
      /// \return A permuted and shifted copy of `arg`
      result_type
      operator()(const argument_type& arg, const Permutation& perm) const {
        return eval(arg, perm);
      }

      /// Consuming shift operation

      /// \tparam A The tile argument type
      /// \param arg The tile argument
      /// \return A shifted copy of `arg`
      template <typename A>
      result_type operator()(A&& arg) const {
        return ScalShift_::template eval<is_consumable>(std::forward<A>(arg));
      }

      /// Explicit consuming shift operation

      /// \param arg The tile argument
      /// \return In-place shifted `arg`
      result_type consume(argument_type& arg) const {
        constexpr bool can_consume = is_consumable_tile<argument_type>::value &&
            std::is_same<result_type, argument_type>::value;
        return ScalShift_::template eval<can_consume>(arg);
      }

    }; // class ScalShift

  } // namesapce detail
} // namespace TiledArray

#endif // TILEDARRAY_TILE_OP_SHIFT_H__INCLUDED
