package com.abstratt.kirra.mdd.rest.impl.v1.resources;

import java.util.ArrayList;
import java.util.List;

import org.apache.commons.lang.StringUtils;
import org.eclipse.uml2.uml.NamedElement;
import org.eclipse.uml2.uml.Operation;
import org.eclipse.uml2.uml.UMLPackage;
import org.restlet.representation.Representation;
import org.restlet.resource.Post;

import com.abstratt.kirra.mdd.rest.KirraRESTUtils;
import com.abstratt.kirra.mdd.rest.impl.v1.resources.TestRunnerResource.TestResult.SourceLocation;
import com.abstratt.kirra.mdd.rest.impl.v1.resources.TestRunnerResource.TestResult.Status;
import com.abstratt.mdd.core.IRepository;
import com.abstratt.mdd.core.RepositoryService;
import com.abstratt.mdd.core.runtime.ExecutionContext.CallSite;
import com.abstratt.mdd.core.runtime.ModelExecutionException;
import com.abstratt.mdd.core.runtime.Runtime;
import com.abstratt.mdd.core.runtime.RuntimeRaisedException;
import com.abstratt.mdd.core.runtime.types.BasicType;
import com.abstratt.mdd.core.util.MDDExtensionUtils;
import com.abstratt.mdd.frontend.web.ResourceUtils;
import com.abstratt.pluginutils.ISharedContextRunnable;

public class TestRunnerResource extends AbstractKirraRepositoryResource {

    static class TestResult {
        static class SourceLocation {
            public String filename;
            public String frameName;
            public Integer lineNumber;

            public SourceLocation(String filename, Integer lineNumber, String frameName) {
                this.filename = filename;
                this.lineNumber = lineNumber;
                this.frameName = frameName;
            }
        }

        enum Status {
            Fail, Pass
        }

        public List<SourceLocation> errorLocation = new ArrayList<SourceLocation>();
        public String testCaseName;
        public String testClassName;
        public String testMessage;
        public Status testStatus;
        public SourceLocation testSourceLocation;

        public TestResult(String testClassName, String testCaseName, Status testStatus, String testMessage,
                SourceLocation testSourceLocation) {
            this.testClassName = testClassName;
            this.testCaseName = testCaseName;
            this.testStatus = testStatus;
            this.testMessage = testMessage;
            this.testSourceLocation = testSourceLocation;
        }
    }

    @Post
    public Representation runTest(Representation noneExpected) {
        final Representation[] result = { null };
        try {
            KirraRESTUtils.runInKirraRepository(getRequest(), new ISharedContextRunnable<IRepository, Representation>() {
                @Override
                public Representation runInContext(IRepository context) {
                    result[0] = doRunTest();
                    // avoid saving
                    throw new RuntimeException();
                }
            });
        } catch (RuntimeException e) {
            if (result[0] != null)
                return result[0];
            throw e;
        }
        return result[0];
    }

    private Representation doRunTest() {
        final IRepository repository = RepositoryService.DEFAULT.getFeature(IRepository.class);
        final Runtime runtime = RepositoryService.DEFAULT.getFeature(Runtime.class);
        final String testClassName = (String) getRequestAttributes().get("testClassName");
        final String testCaseName = (String) getRequestAttributes().get("testCaseName");

        Operation testCase = repository.findNamedElement(testClassName.replace(".", NamedElement.SEPARATOR) + NamedElement.SEPARATOR
                + testCaseName, UMLPackage.Literals.OPERATION, null);
        ResourceUtils.ensure(testCase != null, "Could not find operation", null);
        ResourceUtils.ensure(TestResource.isTestCase(testCase), "Not a test case operation", null);
        SourceLocation testLocation = findOperationLocation(testCase);
        try {
            BasicType instance = runtime.newInstance(testCase.getClass_());
            runtime.runOperation(null, instance, testCase);
            runtime.saveContext(false);
            if (TestResource.shouldFail(testCase)) {
                String errorMessage = "Should have failed";
                String expectedContext = TestResource.getExpectedContext(testCase);
                String expectedConstraint = TestResource.getExpectedConstraint(testCase);
                if (expectedContext != null)
                    errorMessage += " - expected context: " + expectedContext;
                if (expectedConstraint != null)
                    errorMessage += " - expected constraint: " + expectedConstraint;
                TestResult testResult = new TestResult(testClassName, testCaseName, TestResult.Status.Fail, errorMessage, testLocation);
                SourceLocation location = findOperationLocation(testCase);
                if (location != null)
                    testResult.errorLocation.add(location);
                return jsonToStringRepresentation(testResult);
            }

            TestResult pass = new TestResult(testClassName, testCaseName, TestResult.Status.Pass, null, testLocation);
            return jsonToStringRepresentation(pass);
        } catch (ModelExecutionException mee) {
            String message = mee.getMessage();
            if (TestResource.shouldFail(testCase)) {
                String expectedContext = TestResource.getExpectedContext(testCase);
                String expectedConstraint = TestResource.getExpectedConstraint(testCase);
                String actualConstraint = null;
                if (mee instanceof RuntimeRaisedException) {
                    RuntimeRaisedException rre = (RuntimeRaisedException) mee;
                    actualConstraint = rre.getConstraint() == null ? null : rre.getConstraint().getName();
                }
                String actualContext = mee.getContext() == null ? null : mee.getContext().getName();
                boolean matchExpectation = true;
                if (!StringUtils.isBlank(expectedContext)
                        && !StringUtils.trimToEmpty(expectedContext).equals(StringUtils.trimToEmpty(actualContext))) {
                    matchExpectation = false;
                    message += " - Expected context: " + expectedContext + ", actual: " + actualContext;
                }
                if (!StringUtils.isBlank(expectedConstraint)
                        && !StringUtils.trimToEmpty(expectedConstraint).equals(StringUtils.trimToEmpty(actualConstraint))) {
                    matchExpectation = false;
                    message += " - Expected constraint: " + expectedConstraint + ", actual: " + actualConstraint;
                }
                return jsonToStringRepresentation(new TestResult(testClassName, testCaseName, matchExpectation ? Status.Pass : Status.Fail,
                        matchExpectation ? null : message, testLocation));
            }

            TestResult testResult = new TestResult(testClassName, testCaseName, TestResult.Status.Fail, message, testLocation);
            for (CallSite callSite : mee.getCallSites())
                testResult.errorLocation
                        .add(new SourceLocation(callSite.getSourceFile(), callSite.getLineNumber(), callSite.getFrameName()));
            return jsonToStringRepresentation(testResult);
        } catch (RuntimeException rre) {
            TestResult testResult = new TestResult(testClassName, testCaseName, TestResult.Status.Fail, rre.toString(), testLocation);
            return jsonToStringRepresentation(testResult);
        }
    }

    private SourceLocation findOperationLocation(Operation operation) {
        return new SourceLocation(MDDExtensionUtils.getSource(operation), MDDExtensionUtils.getLineNumber(operation),
                operation.getQualifiedName());
    }
}