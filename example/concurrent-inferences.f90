! Copyright (c), The Regents of the University of California
! Terms of use are as specified in LICENSE.txt
program concurrent_inferences
  !! This program demonstrates how to read a neural network from a JSON file
  !! and use the network to perform concurrent inferences.
  use fiats_m, only : neural_network_t, tensor_t, double_precision, double_precision_string_t, double_precision_file_t
  use julienne_m, only : string_t, command_line_t, file_t
  use assert_m, only : assert
  use iso_fortran_env, only : int64, real64
  use omp_lib
  implicit none

  type(string_t) network_file_name
  type(command_line_t) command_line

  network_file_name = string_t(command_line%flag_value("--network"))

  if (len(network_file_name%string())==0) then
    error stop new_line('a') // new_line('a') // &
      'Usage: fpm run --example concurrent-inferences --profile release --flag "-fopenmp" -- --network "<file-name>"'
  end if

  block
    integer, parameter :: lat=263, lon=317, lev=15 ! latitudes, longitudes, levels (elevations)
    integer i, j, k

    single_precision_inference: &
    block
      integer(int64) t_start, t_finish, clock_rate

      type(neural_network_t) neural_network
      type(tensor_t), allocatable :: inputs(:,:,:), outputs(:,:,:)
      real, allocatable :: input_components(:,:,:,:)

      print *, "Constructing a new neural_network_t object from the file " // network_file_name%string()
      neural_network = neural_network_t(file_t(network_file_name))

      print *,"Defining an array of tensor_t input objects with random normalized components"
      allocate(outputs(lat,lev,lon))
      allocate( inputs(lat,lev,lon))
      allocate(input_components(lat,lev,lon,neural_network%num_inputs()))
      call random_number(input_components)

      do concurrent(i=1:lat, k=1:lev, j=1:lon)
        inputs(i,k,j) = tensor_t(input_components(i,k,j,:))
      end do

      print *,"Performing",lat*lev*lon," inferences inside `do concurrent`."
      call system_clock(t_start, clock_rate)
      do concurrent(i=1:lat, k=1:lev, j=1:lon)
        outputs(i,k,j) = neural_network%infer(inputs(i,k,j))
      end do
      call system_clock(t_finish)
      print *,"Elapsed system clock: ", real(t_finish - t_start, real64)/real(clock_rate, real64)

      print *,"Performing",lat*lev*lon," inferences inside `omp parallel do`."
      call system_clock(t_start, clock_rate)
      !$omp parallel do shared(inputs,outputs)
      do j=1,lon
        do k=1,lev
          do i=1,lat
            outputs(i,k,j) = neural_network%infer(inputs(i,k,j))
          end do
        end do
      end do
      !$omp end parallel do
      call system_clock(t_finish)
      print *,"Elapsed system clock: ", real(t_finish - t_start, real64)/real(clock_rate, real64)

      print *,"Performing elemental inferences inside `omp workshare`"
      call system_clock(t_start, clock_rate)
      !$omp workshare
      outputs = neural_network%infer(inputs)
      !$omp end workshare
      call system_clock(t_finish)
      print *,"Elapsed system clock: ", real(t_finish - t_start, real64)/real(clock_rate, real64)

    end block single_precision_inference

    double_precision_inference: &
    block
      integer(int64) t_start, t_finish, clock_rate

      type(neural_network_t(double_precision)) neural_network
      type(tensor_t(double_precision)), allocatable :: inputs(:,:,:), outputs(:,:,:)
      double precision, allocatable :: input_components(:,:,:,:)

      print *, "Constructing a new neural_network_t object from the file " // network_file_name%string()
      neural_network = neural_network_t(double_precision_file_t(network_file_name))

      print *,"Defining an array of tensor_t input objects with random normalized components"
      allocate(outputs(lat,lon,lev))
      allocate( inputs(lat,lon,lev))
      allocate(input_components(lat,lon,lev,neural_network%num_inputs()))
      call random_number(input_components)

      do concurrent(i=1:lat, j=1:lon, k=1:lev)
        inputs(i,j,k) = tensor_t(input_components(i,j,k,:))
      end do

      print *,"Performing double-precision concurrent inference"
      call system_clock(t_start, clock_rate)
      do concurrent(i=1:lat, j=1:lon, k=1:lev)
        outputs(i,j,k) = neural_network%infer(inputs(i,j,k))
      end do
      call system_clock(t_finish)
      print *,"Double-precision concurrent inference time: ", real(t_finish - t_start, real64)/real(clock_rate, real64)

    end block double_precision_inference

  end block

end program
