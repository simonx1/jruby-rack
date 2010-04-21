#--
# Copyright (c) 2010 Engine Yard, Inc.
# Copyright (c) 2007-2009 Sun Microsystems, Inc.
# This source code is available under the MIT license.
# See the file LICENSE.txt for details.
#++

require File.dirname(__FILE__) + '/../spec_helper'

import org.jruby.rack.RackFilter

describe RackFilter do
  before :each do
    stub_request("/index")
    @response = javax.servlet.http.HttpServletResponse.impl {}
    @chain = mock "filter chain"
    @dispatcher = mock "dispatcher"
    @filter = RackFilter.new @dispatcher
  end

  def stub_request(path_info)
    @request = javax.servlet.http.HttpServletRequest.impl {}
    @request.stub!(:setAttribute)
    @request.stub!(:getServletPath).and_return("/some/uri")
    @request.stub!(:getPathInfo).and_return(path_info)
  end

  it "should dispatch the filter chain and finish if the chain resulted in a successful response" do
    @chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.setStatus(200)
    end
    @response.should_receive(:setStatus).ordered.with(200)
    @filter.doFilter(@request, @response, @chain)
  end

  it "should finish if the chain resulted in a redirect" do
    @chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendRedirect("/some/url")
    end
    @response.should_receive(:sendRedirect).ordered.with("/some/url")
    @filter.doFilter(@request, @response, @chain)    
  end

  it "should dispatch to the rack dispatcher if the chain resulted in a client or server error" do
    @chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(404)
    end
    @response.should_receive(:setStatus).ordered
    @request.should_receive(:setAttribute).ordered.with(org.jruby.rack.RackEnvironment::DYNAMIC_REQS_ONLY, true)
    @dispatcher.should_receive(:process).with(@request,@response).ordered
    @filter.doFilter(@request, @response, @chain)    
  end

  it "should allow downstream entities to flush the buffer in the case of a successful response" do
    @chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.setStatus(200)
      resp.flushBuffer
    end
    
    @response.should_receive(:setStatus).ordered.with(200)
    @response.should_receive(:flushBuffer).ordered
    @filter.doFilter(@request, @response, @chain)    
  end

  it "should not allow downstream entities in the chain to flush the buffer in the case of an error" do
    @chain.should_receive(:doFilter).ordered.and_return do |_, resp|
      resp.sendError(400)
      resp.flushBuffer
    end
    @response.should_not_receive(:flushBuffer)
    @response.should_receive(:setStatus).ordered
    @dispatcher.should_receive(:process).ordered.with(@request,@response)
    @filter.doFilter(@request, @response, @chain)
  end

  it "should dispatch /some/uri/index to the filter chain as /some/uri/index.html" do
    @chain.should_receive(:doFilter).ordered.and_return do |req,resp|
      req.getPathInfo.should == "/index.html"
      resp.setStatus(200)
    end
    @response.should_receive(:setStatus).ordered.with(200)
    @filter.doFilter(@request, @response, @chain)
  end

  it "should dispatch /some/uri/index.html unchanged" do
    stub_request("/index.html")
    @chain.should_receive(:doFilter).ordered.and_return do |req,resp|
      req.getPathInfo.should == "/index.html"
      resp.setStatus(200)
    end
    @response.should_receive(:setStatus).ordered.with(200)
    @filter.doFilter(@request, @response, @chain)
  end

  it "should dispatch to /some/uri.html if there is no path info" do
    stub_request(nil)
    @chain.should_receive(:doFilter).ordered.and_return do |req,resp|
      req.getServletPath.should == "/some/uri.html"
      req.getPathInfo.should == nil
      resp.setStatus(200)
    end
    @response.should_receive(:setStatus).ordered.with(200)
    @filter.doFilter(@request, @response, @chain)
  end
end
