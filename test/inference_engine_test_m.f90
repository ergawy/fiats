! Copyright (c), The Regents of the University of California
! Terms of use are as specified in LICENSE.txt
module inference_engine_test_m
  !! Define inference tests and procedures required for reporting results
  use string_m, only : string_t
  use test_m, only : test_t
  use test_result_m, only : test_result_t
  use inference_engine_m, only : inference_engine_t, inputs_t, outputs_t
  use inference_strategy_m, only : inference_strategy_t
  use matmul_m, only : matmul_t
  use file_m, only : file_t
  use kind_parameters_m, only : rkind
  implicit none

  private
  public :: inference_engine_test_t

  type, extends(test_t) :: inference_engine_test_t
  contains
    procedure, nopass :: subject
    procedure, nopass :: results
  end type

contains

  pure function subject() result(specimen)
    character(len=:), allocatable :: specimen
    specimen = "An inference_engine_t that encodes an XOR gate" 
  end function

  function results() result(test_results)
    type(test_result_t), allocatable :: test_results(:)

    test_results = test_result_t( &
      [ character(len=len("mapping (true,true) to false using the default ('do concurrent'/dot_product) inference strategy")) :: &
        "mapping (true,true) to false using the default ('do concurrent'/dot_product) inference strategy", &
        "mapping (true,false) to true using the default inference strategy", &
        "mapping (false,true) to true using the default inference strategy", &
        "mapping (false,false) to false using the default inference strategy", &
        "mapping (true,true) to false using `matmul`-based inference strategy", &
        "mapping (true,false) to true using `matmul`-based inference strategy", &
        "mapping (false,true) to true using `matmul`-based inference strategy", &
        "mapping (false,false) to false using `matmul`-based inference strategy", &
        "writing and then reading itself to and from a file", &
        "converting to and from JSON format", &
        "performing inference with encapsulated inputs and outputs" &
      ], [xor_truth_table(), xor_truth_table(matmul_t()), write_then_read(), convert_to_and_from_json(), elemental_inference()] &
    )
  end function

  function xor_network(inference_strategy) result(inference_engine)

    type(inference_engine_t) inference_engine
    integer, parameter :: n_in = 2 ! number of inputs
    integer, parameter :: n_out = 1 ! number of outputs
    integer, parameter :: neurons = 3 ! number of neurons per layer
    integer, parameter :: n_hidden = 2 ! number of hidden layers 
    integer i, j 
    integer, parameter :: identity(*,*,*) = &
      reshape([((merge(1,0,i==j), i=1,neurons), j=1,neurons)], shape=[neurons,neurons,n_hidden-1])
    class(inference_strategy_t), intent(in), optional :: inference_strategy
   
    inference_engine = inference_engine_t( &
      input_weights = real(reshape([1,0,1,1,0,1], [n_in, neurons]), rkind), &
      hidden_weights = real(identity, rkind), &
      output_weights = real(reshape([1,-2,1], [n_out, neurons]), rkind), &
      biases = reshape([real(rkind):: 0.,-1.99,0., 0.,0.,0.], [neurons, n_hidden]), &
      output_biases = [real(rkind):: 0.], &
      inference_strategy = inference_strategy &
    )
  end function

  function write_then_read() result(test_passes)
    logical, allocatable :: test_passes

    type(inference_engine_t) xor_written, xor_read, difference

    xor_written = xor_network()
    call xor_written%write_network(string_t("build/write_then_read_test_specimen"))
    call xor_read%read_network(string_t("build/write_then_read_test_specimen"))

    block 
      type(inference_engine_t) difference
      real(rkind), parameter :: tolerance = 1.0E-06_rkind

      difference = xor_read - xor_written
      test_passes = difference%norm() < tolerance
    end block
  end function

  function convert_to_and_from_json() result(test_passes)
    logical, allocatable :: test_passes
    type(inference_engine_t) xor, difference
    real, parameter :: tolerance = 1.0E-06

    xor = xor_network()
    difference = inference_engine_t(xor%to_json())- xor
    test_passes = difference%norm() < tolerance
  end function

  function xor_truth_table(inference_strategy) result(test_passes)
    logical, allocatable :: test_passes(:)
    class(inference_strategy_t), intent(in), optional :: inference_strategy

    type(inference_engine_t) inference_engine

    inference_engine = xor_network(inference_strategy)

    block
      real(rkind), parameter :: tolerance = 1.E-08_rkind, false = 0._rkind, true = 1._rkind

      associate( &
        true_true => inference_engine%infer(input=[true,true]), & 
        true_false => inference_engine%infer(input=[true,false]), &
        false_true => inference_engine%infer(input=[false,true]), &
        false_false => inference_engine%infer(input=[false,false]) &
      )
        test_passes = [ &
          size(true_true)==1 .and. abs(true_true(1) - false) < tolerance, &
          size(true_false)==1 .and. abs(true_false(1) - true) < tolerance,  &
          size(false_true)==1 .and. abs(false_true(1) - true) < tolerance, &
          size(false_false)==1 .and. abs(false_false(1) - false) < tolerance  &
        ]
      end associate
    end block

  end function

  function elemental_inference(inference_strategy) result(test_passes)
    logical, allocatable :: test_passes(:)
    class(inference_strategy_t), intent(in), optional :: inference_strategy
    type(inference_engine_t) inference_engine

    inference_engine = xor_network(inference_strategy)

    block
      type(outputs_t) true_true, true_false, false_true, false_false
      real(rkind), parameter :: tolerance = 1.E-08_rkind, false = 0._rkind, true = 1._rkind

      true_true = inference_engine%infer(inputs=inputs_t([true,true]))
      true_false = inference_engine%infer(inputs=inputs_t([true,false]))
      false_true = inference_engine%infer(inputs=inputs_t([false,true]))
      false_false = inference_engine%infer(inputs=inputs_t([false,false]))

      test_passes = [ &
        abs(true_true%outputs_ - false) < tolerance .and. abs(true_false%outputs_ - true) < tolerance .and. &
        abs(false_true%outputs_ - true) < tolerance .and. abs(false_false%outputs_ - false) < tolerance &
      ]
    end block
  end function

end module inference_engine_test_m