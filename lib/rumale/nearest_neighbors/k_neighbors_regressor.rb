# frozen_string_literal: true

require 'rumale/base/base_estimator'
require 'rumale/base/regressor'

module Rumale
  module NearestNeighbors
    # KNeighborsRegressor is a class that implements the regressor with the k-nearest neighbors rule.
    # The current implementation uses the Euclidean distance for finding the neighbors.
    #
    # @example
    #   estimator =
    #     Rumale::NearestNeighbors::KNeighborsRegressor.new(n_neighbors: 5)
    #   estimator.fit(training_samples, traininig_target_values)
    #   results = estimator.predict(testing_samples)
    #
    class KNeighborsRegressor
      include Base::BaseEstimator
      include Base::Regressor

      # Return the prototypes for the nearest neighbor regressor.
      # If the metric is 'precomputed', that returns nil.
      # @return [Numo::DFloat] (shape: [n_testing_samples, n_features])
      attr_reader :prototypes

      # Return the values of the prototypes
      # @return [Numo::DFloat] (shape: [n_testing_samples, n_outputs])
      attr_reader :values

      # Create a new regressor with the nearest neighbor rule.
      #
      # @param n_neighbors [Integer] The number of neighbors.
      # @param metric [String] The metric to calculate the distances.
      #   If metric is 'euclidean', Euclidean distance is calculated for distance between points.
      #   If metric is 'precomputed', the fit and predict methods expect to be given a distance matrix.
      def initialize(n_neighbors: 5, metric: 'euclidean')
        check_params_numeric(n_neighbors: n_neighbors)
        check_params_positive(n_neighbors: n_neighbors)
        @params = {}
        @params[:n_neighbors] = n_neighbors
        @params[:metric] = metric == 'precomputed' ? 'precomputed' : 'euclidean'
        @prototypes = nil
        @values = nil
      end

      # Fit the model with given training data.
      #
      # @param x [Numo::DFloat] (shape: [n_training_samples, n_features]) The training data to be used for fitting the model.
      #   If the metric is 'precomputed', x must be a square distance matrix (shape: [n_training_samples, n_training_samples]).
      # @param y [Numo::DFloat] (shape: [n_training_samples, n_outputs]) The target values to be used for fitting the model.
      # @return [KNeighborsRegressor] The learned regressor itself.
      def fit(x, y)
        x = check_convert_sample_array(x)
        y = check_convert_tvalue_array(y)
        check_sample_tvalue_size(x, y)
        raise ArgumentError, 'Expect the input distance matrix to be square.' if @params[:metric] == 'precomputed' && x.shape[0] != x.shape[1]
        @prototypes = x.dup unless @params[:metric] == 'precomputed'
        @values = y.dup
        self
      end

      # Predict values for samples.
      #
      # @param x [Numo::DFloat] (shape: [n_training_samples, n_features]) The samples to predict the values.
      #   If the metric is 'precomputed', x must be a square distance matrix (shape: [n_testing_samples, n_training_samples]).
      # @return [Numo::DFloat] (shape: [n_training_samples, n_outputs]) Predicted values per sample.
      def predict(x)
        x = check_convert_sample_array(x)
        if @params[:metric] == 'precomputed' && x.shape[1] != @values.shape[0]
          raise ArgumentError, 'Expect the size input matrix to be n_testing_samples-by-n_training_samples.'
        end
        # Initialize some variables.
        n_samples = x.shape[0]
        n_prototypes, n_outputs = @values.shape
        n_neighbors = [@params[:n_neighbors], n_prototypes].min
        # Calculate distance matrix.
        distance_matrix = @params[:metrix] == 'precomputed' ? x : PairwiseMetric.euclidean_distance(x, @prototypes)
        # Predict values for the given samples.
        predicted_values = Array.new(n_samples) do |n|
          neighbor_ids = distance_matrix[n, true].to_a.each_with_index.sort.map(&:last)[0...n_neighbors]
          n_outputs.nil? ? @values[neighbor_ids].mean : @values[neighbor_ids, true].mean(0).to_a
        end
        Numo::DFloat[*predicted_values]
      end

      # Dump marshal data.
      # @return [Hash] The marshal data about KNeighborsRegressor.
      def marshal_dump
        { params: @params,
          prototypes: @prototypes,
          values: @values }
      end

      # Load marshal data.
      # @return [nil]
      def marshal_load(obj)
        @params = obj[:params]
        @prototypes = obj[:prototypes]
        @values = obj[:values]
        nil
      end
    end
  end
end
