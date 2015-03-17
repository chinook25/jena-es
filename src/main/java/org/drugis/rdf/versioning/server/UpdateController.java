package org.drugis.rdf.versioning.server;

import java.io.IOException;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.apache.jena.riot.WebContent;
import org.drugis.rdf.versioning.store.DatasetGraphEventSourcing;
import org.drugis.rdf.versioning.store.EventSource;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;

import com.hp.hpl.jena.query.QueryParseException;
import com.hp.hpl.jena.query.Syntax;
import com.hp.hpl.jena.sparql.modify.UsingList;
import com.hp.hpl.jena.update.UpdateAction;

@Controller
@RequestMapping("/datasets/{datasetId}/update")
public class UpdateController {
	@Autowired EventSource d_eventSource;

	@RequestMapping(method=RequestMethod.POST, consumes=WebContent.contentTypeSPARQLUpdate)
	public Object update(
			@PathVariable String datasetId,
			final HttpServletRequest request,
			@RequestHeader(value="X-Accept-EventSource-Version", required=false) String version,
			HttpServletResponse response)
			throws Exception { // TODO: request parameters
		final DatasetGraphEventSourcing dataset = Util.getDataset(d_eventSource, datasetId);
		final UsingList usingList = new UsingList();

		Runnable action = new Runnable() {
			@Override
			public void run() {
				try {
					UpdateAction.parseExecute(usingList, dataset, request.getInputStream(), Config.BASE_URI, Syntax.syntaxARQ);
				} catch (QueryParseException e) {
					throw new RequestParseException(e);
				} catch (IOException e) {
					throw new RuntimeException(e);
				}
			}
		};

		String newVersion = Util.runReturningVersion(dataset, version, action, Util.versionMetaData(request));
		response.setHeader("X-EventSource-Version", newVersion);
		return null;
	}
}
