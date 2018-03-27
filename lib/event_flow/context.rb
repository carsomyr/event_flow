# -*- coding: utf-8 -*-
#
# Copyright 2018 Roy Liu
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.

require "set"
require "tsort"

module EventFlow
  module Context
    class SubscriberSorter
      include TSort

      attr_reader :event, :context, :subscribers

      def initialize(event, context, subscribers)
        @event = event
        @context = context
        @subscribers = subscribers
      end

      def tsort_each_node(&block)
        subscribers.each(&block)
      end

      def tsort_each_child(subscriber, &block)
        subscriber.send("#{event}_flow_dependencies", context).each(&block)
      end
    end

    def self.included(clazz)
      clazz.send(:include, InstanceMethods)
      clazz.send(:extend, ClassMethods)
    end

    module InstanceMethods
      def publish(event, *args, &block)
        block = block || Proc.new {|_|}

        subscribers_unsorted = send("#{event}_flow_subscribers")

        SubscriberSorter.new(event, self, subscribers_unsorted).tsort.each do |subscriber|
          block.call(subscriber.send("on_#{event}", *args))
        end
      end
    end

    module ClassMethods
      def event_flows(*events)
        events.each do |event|
          m = Module.new do
            define_method("#{event}_flow_subscribers") do
              send("visit_#{event}_flow_dependencies").to_a
            end

            define_method("visit_#{event}_flow_dependencies") do |node = self, visited = Set.new|
              return \
                if !visited.add?(node)

              send("#{event}_flow_dependencies", self).each do |node|
                send("visit_#{event}_flow_dependencies", node, visited)
              end

              visited
            end
          end

          send(:include, m)
        end
      end
    end
  end
end
